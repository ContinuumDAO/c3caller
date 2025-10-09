#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <C3CALLER>"
    echo "Example: $0 0x1234..."
    exit 1
fi

C3CALLER=$1

./helpers/get-all-operators/arbitrum-sepolia.sh $1
./helpers/get-all-operators/bsc-testnet.sh $1
./helpers/get-all-operators/sepolia.sh $1
./helpers/get-all-operators/base-sepolia.sh $1
./helpers/get-all-operators/scroll-sepolia.sh $1
./helpers/get-all-operators/avalanche-fuji.sh $1
./helpers/get-all-operators/opbnb-testnet.sh $1
./helpers/get-all-operators/holesky.sh $1
./helpers/get-all-operators/soneium-minato-testnet.sh $1
