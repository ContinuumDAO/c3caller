#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    exit 1
fi

# Fee config env vars for InitC3DApp (script runs setFeeConfig then initDAppConfig)
eval $(node "$PROJECT_ROOT/js-helpers/get-fee-config.js" --chain-id 59902)
export DAPP_MANAGER FEE_TOKEN PAYLOAD_PER_BYTE_FEE GAS_PER_ETHER_FEE

# Metis Sepolia RPC does not support eth_feeHistory (EIP-1559); use legacy txs.
# Simulate the dapp initiation (setFeeConfig + initDAppConfig in one script). Use same account as broadcast so onlyGov (setFeeConfig) passes.
forge script script/InitC3DApp.s.sol \
--account $1 \
--password-file $2 \
--rpc-url metis-sepolia-rpc-url \
--chain-id 59902 \
--legacy

if [ $? -ne 0 ]; then
    echo "Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with dapp initiation? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "DApp initiation cancelled."
    exit 1
fi

echo "Proceeding with dapp initiation..."

eval $(node "$PROJECT_ROOT/js-helpers/get-fee-config.js" --chain-id 59902)
export DAPP_MANAGER FEE_TOKEN PAYLOAD_PER_BYTE_FEE GAS_PER_ETHER_FEE

forge script script/InitC3DApp.s.sol \
--account $1 \
--password-file $2 \
--slow \
--rpc-url metis-sepolia-rpc-url \
--chain-id 59902 \
--legacy \
--gas-estimate-multiplier ${INIT_C3DAPP_GAS_ESTIMATE_MULTIPLIER:-120} \
--broadcast

echo "DApp initiation complete."
