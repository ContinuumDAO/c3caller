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

# Metis Sepolia RPC does not support eth_feeHistory (EIP-1559); use legacy txs.
# Simulate the deployment
forge script script/DeployProtocolContracts.s.sol \
--sender $(cast wallet address --account $1 --password-file $2) \
--rpc-url metis-sepolia-rpc-url \
--chain-id 59902 \
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
--etherscan-api-key metis-sepolia-key \
--slow \
--rpc-url metis-sepolia-rpc-url \
--chain-id 59902 \
--legacy \
--broadcast

echo "Deployment and verification complete."
echo "Saving addresses to deployments.toml and contract-addresses.json..."
"$SCRIPT_DIR/run-save-addresses.sh"
