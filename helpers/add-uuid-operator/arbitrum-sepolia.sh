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

# Simulate the operation
forge script script/AddUUIDOperator.s.sol \
--account $1 \
--password-file $2 \
--rpc-url arbitrum-sepolia-rpc-url \
--chain arbitrum-sepolia

# Check if the simulation succeeded
if [ $? -ne 0 ]; then
    echo "Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with add operator operation? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "Add operator operation cancelled."
    exit 1
fi

echo "Proceeding with add operator operation..."

forge script script/AddUUIDOperator.s.sol \
--account $1 \
--password-file $2 \
--slow \
--rpc-url arbitrum-sepolia-rpc-url \
--chain arbitrum-sepolia \
--broadcast

echo "Add operator operation complete."
