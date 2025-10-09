#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <C3CALLER>"
    echo "Example: $0 0x1234..."
    exit 1
fi

C3CALLER=$1

echo -e "\nArbitrum Sepolia:"

cast call $C3CALLER \
    "getAllOperators()(address[])" \
    --rpc-url arbitrum-sepolia-rpc-url \
    --chain arbitrum-sepolia | \
tr -d '[]' | \
tr ',' '\n' | \
sed '1s/^/    /; 2,$s/^/   /' | \
sed '1i\
[' | \
sed '$a\
]'
