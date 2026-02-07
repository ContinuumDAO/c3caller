#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    exit 1
fi

# Lightlink Pegasus RPC does not support EIP-1559; use legacy txs.
forge script script/InitC3DApp.s.sol \
--rpc-url lightlink-pegasus-testnet-rpc-url \
--chain-id 1891 \
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

forge script script/InitC3DApp.s.sol \
--account $1 \
--password-file $2 \
--verify \
--verifier blockscout \
--verifier-url https://pegasus.lightlink.io/api \
--etherscan-api-key lightlink-pegasus-testnet-key \
--slow \
--rpc-url lightlink-pegasus-testnet-rpc-url \
--chain-id 1891 \
--legacy \
--broadcast

echo "DApp initiation and verification complete."
