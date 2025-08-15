#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 0x1234... /path/to/password.txt"
    exit 1
fi

# Simulate the operation
forge script script/AddMPC.s.sol \
--account $1 \
--password-file $2 \
--rpc-url base-sepolia-rpc-url \
--chain base-sepolia

# Check if the simulation succeeded
if [ $? -ne 0 ]; then
    echo "Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with add MPC operation? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "Add MPC operation cancelled."
    exit 1
fi

echo "Proceeding with add MPC operation..."

forge script script/AddMPC.s.sol \
--account $1 \
--password-file $2 \
--slow \
--rpc-url base-sepolia-rpc-url \
--chain base-sepolia \
--broadcast

echo "Add MPC operation complete."
