#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Check if required arguments are provided
if [ $# -lt 3 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <CHAIN_ID> <ACCOUNT> <PASSWORD_FILE> [FEE_MINIMUM_DEPOSIT] [DEPOSIT_AMOUNT]"
    echo "  CHAIN_ID: numeric chain id (e.g. 421614 for Arbitrum Sepolia)"
    echo "Example: $0 421614 0x1234... /path/to/password.txt"
    exit 1
fi

CHAIN_ID="$1"
ACCOUNT="$2"
PASSWORD_FILE="$3"
[ -n "${4:-}" ] && export FEE_MINIMUM_DEPOSIT="$4"
[ -n "${5:-}" ] && export DEPOSIT_AMOUNT="$5"

# Fee config and RPC URL from deployments.toml
eval $(node "$PROJECT_ROOT/js-helpers/get-config-for-chain.js" --chain-id "$CHAIN_ID")
export DAPP_MANAGER FEE_TOKEN PAYLOAD_PER_BYTE_FEE GAS_PER_ETHER_FEE
RPC_URL="${!RPC_URL_ENV}"
[ -z "$RPC_URL" ] && { echo "Error: RPC URL env \$$RPC_URL_ENV not set."; exit 1; }

# Simulate the dapp update (setFeeConfig + updateDAppConfig in one script). Use same account as broadcast so onlyGov (setFeeConfig) passes.
forge script script/UpdateC3DApp.s.sol \
--account "$ACCOUNT" \
--password-file "$PASSWORD_FILE" \
--rpc-url "$RPC_URL" \
--legacy \
--chain-id "$CHAIN_ID"

# Check if the simulation succeeded
if [ $? -ne 0 ]; then
    echo "Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with dapp update? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "DApp update cancelled."
    exit 1
fi

echo "Proceeding with dapp update..."

eval $(node "$PROJECT_ROOT/js-helpers/get-config-for-chain.js" --chain-id "$CHAIN_ID")
export DAPP_MANAGER FEE_TOKEN PAYLOAD_PER_BYTE_FEE GAS_PER_ETHER_FEE
RPC_URL="${!RPC_URL_ENV}"

forge script script/UpdateC3DApp.s.sol \
--account "$ACCOUNT" \
--password-file "$PASSWORD_FILE" \
--slow \
--rpc-url "$RPC_URL" \
--chain-id "$CHAIN_ID" \
--gas-estimate-multiplier 200 \
--legacy \
--broadcast

echo "DApp update complete."
