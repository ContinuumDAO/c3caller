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

# Same chain order as helpers/nonces.sh
./helpers/get-all-operators/bsc-testnet.sh $C3CALLER
./helpers/get-all-operators/soneium-minato-testnet.sh $C3CALLER
./helpers/get-all-operators/opbnb-testnet.sh $C3CALLER
./helpers/get-all-operators/plume-testnet.sh $C3CALLER
./helpers/get-all-operators/base-sepolia.sh $C3CALLER
./helpers/get-all-operators/arbitrum-sepolia.sh $C3CALLER
./helpers/get-all-operators/scroll-sepolia.sh $C3CALLER
./helpers/get-all-operators/sonic-blaze.sh $C3CALLER
./helpers/get-all-operators/amoy.sh $C3CALLER
./helpers/get-all-operators/optimism-sepolia.sh $C3CALLER
./helpers/get-all-operators/sepolia.sh $C3CALLER
./helpers/get-all-operators/fuji.sh $C3CALLER
./helpers/get-all-operators/linea-sepolia.sh $C3CALLER
./helpers/get-all-operators/mantle-sepolia.sh $C3CALLER
./helpers/get-all-operators/zksync-testnet.sh $C3CALLER
./helpers/get-all-operators/celo-sepolia.sh $C3CALLER
./helpers/get-all-operators/hoodi.sh $C3CALLER
./helpers/get-all-operators/monad-testnet.sh $C3CALLER
./helpers/get-all-operators/core-testnet.sh $C3CALLER
./helpers/get-all-operators/rsk-testnet.sh $C3CALLER
./helpers/get-all-operators/bitlayer-testnet.sh $C3CALLER
./helpers/get-all-operators/lens-testnet.sh $C3CALLER
./helpers/get-all-operators/manta-sepolia.sh $C3CALLER
./helpers/get-all-operators/megaeth-testnet.sh $C3CALLER
./helpers/get-all-operators/abstract-testnet.sh $C3CALLER
./helpers/get-all-operators/mantra-testnet.sh $C3CALLER
./helpers/get-all-operators/shape-sepolia.sh $C3CALLER
./helpers/get-all-operators/tempo-moderato.sh $C3CALLER
./helpers/get-all-operators/berachain-bepolia.sh $C3CALLER
./helpers/get-all-operators/kairos-testnet.sh $C3CALLER
./helpers/get-all-operators/redbelly-testnet.sh $C3CALLER
