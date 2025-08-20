#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 0x1234... /path/to/password.txt"
    exit 1
fi

./helpers/add-uuid-operator/arbitrum-sepolia.sh $1 $2
./helpers/add-uuid-operator/avalanche-fuji.sh $1 $2
./helpers/add-uuid-operator/base-sepolia.sh $1 $2
./helpers/add-uuid-operator/bsc-testnet.sh $1 $2
./helpers/add-uuid-operator/holesky.sh $1 $2
./helpers/add-uuid-operator/opbnb-testnet.sh $1 $2
./helpers/add-uuid-operator/scroll-sepolia.sh $1 $2
./helpers/add-uuid-operator/sepolia.sh $1 $2
./helpers/add-uuid-operator/soneium-minato-testnet.sh $1 $2
