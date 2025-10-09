#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 0x1234... /path/to/password.txt"
    exit 1
fi

./helpers/new-operator/arbitrum-sepolia.sh $1 $2
./helpers/new-operator/bsc-testnet.sh $1 $2
./helpers/new-operator/sepolia.sh $1 $2
./helpers/new-operator/avalanche-fuji.sh $1 $2
./helpers/new-operator/base-sepolia.sh $1 $2
./helpers/new-operator/holesky.sh $1 $2
./helpers/new-operator/opbnb-testnet.sh $1 $2
./helpers/new-operator/scroll-sepolia.sh $1 $2
./helpers/new-operator/soneium-minato-testnet.sh $1 $2