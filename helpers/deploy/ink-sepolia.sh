#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 0x1234... /path/to/password.txt"
    exit 1
fi

# Simulate the deployment
forge script script/DeployProtocolContracts.s.sol \
--sender $(cast wallet address --account $1 --password-file $2) \
--rpc-url ink-sepolia-rpc-url \
--chain-id 763373

# Check if the simulation succeeded
if [ $? -ne 0 ]; then
    echo "Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with deployment? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo "Proceeding with deployment..."

# Ink Sepolia uses Blockscout for verification
forge script script/DeployProtocolContracts.s.sol \
--account $1 \
--password-file $2 \
--verify \
--verifier blockscout \
--verifier-url https://explorer-sepolia.inkonchain.com/api \
--etherscan-api-key ink-sepolia-key \
--slow \
--rpc-url ink-sepolia-rpc-url \
--chain-id 763373 \
--broadcast

echo "Deployment and verification complete."
