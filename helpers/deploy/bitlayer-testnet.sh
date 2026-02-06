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

# Simulate the deployment (--legacy to avoid EIP-1559 fee API)
forge script script/DeployProtocolContracts.s.sol \
--rpc-url bitlayer-testnet-rpc-url \
--chain-id 200810 \
--legacy

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

forge script script/DeployProtocolContracts.s.sol \
--account $1 \
--password-file $2 \
--verify \
--etherscan-api-key bitlayer-testnet-key \
--slow \
--rpc-url bitlayer-testnet-rpc-url \
--chain-id 200810 \
--legacy \
--broadcast

echo "Deployment and verification complete."
