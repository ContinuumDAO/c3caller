#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    exit 1
fi

forge script script/InitC3DApp.s.sol \
--rpc-url bob-sepolia-rpc-url \
--chain-id 808813

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
--verifier-url https://bob-sepolia.explorer.gobob.xyz/api \
--etherscan-api-key bob-sepolia-key \
--slow \
--rpc-url bob-sepolia-rpc-url \
--chain-id 808813 \
--broadcast

echo "DApp initiation and verification complete."
