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

SENDER=$(cast wallet address --account "$1" --password-file "$2")

# Simulate the deployment (--sender so _mint recipient is explicit)
forge script script/DeployFeeToken.s.sol --tc DeployFeeToken \
--sender "$SENDER" \
--rpc-url holesky-rpc-url \
--chain holesky \
-- "$SENDER"

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

forge script script/DeployFeeToken.s.sol --tc DeployFeeToken \
--account $1 \
--password-file $2 \
--verify \
--etherscan-api-key holesky-key \
--slow \
--rpc-url holesky-rpc-url \
--chain holesky \
--broadcast \
-- "$SENDER"

echo "Deployment and verification complete."
CHAIN_NAME=$(basename "$0" .sh)
echo "Saving fee token to deployments.toml and fee-token.json..."
"$SCRIPT_DIR/run-save-fee-token.sh" "$CHAIN_NAME"
