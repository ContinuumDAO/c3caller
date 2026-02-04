#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <C3CALLER>"
    echo "Example: $0 0x1234..."
    exit 1
fi

C3CALLER=$1

echo -e "\nMegaETH testnet:"

cast call $C3CALLER \
    "getAllMPCAddrs()(address[])" \
    --rpc-url megaeth-testnet-rpc-url \
    --chain megaeth-testnet | \
tr -d '[]' | \
tr ',' '\n' | \
sed '1s/^/    /; 2,$s/^/   /' | \
sed '1i\
[' | \
sed '$a\
]'
