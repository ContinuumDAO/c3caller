#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 0x1234... /path/to/password.txt"
    exit 1
fi

# Simulate the deployment
forge script script/DeployC3Caller.s.sol \
--rpc-url soneium-minato-testnet-rpc-url \
--chain soneium-minato-testnet

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

forge script script/DeployC3Caller.s.sol \
--account $1 \
--password-file $2 \
--slow \
--rpc-url soneium-minato-testnet-rpc-url \
--chain soneium-minato-testnet \
--verify \
--verifier blockscout \
--verifier-url https://soneium-minato.blockscout.com/api/ \
--broadcast

echo "Deployment and verification complete."
