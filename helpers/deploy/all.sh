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

# Same chain order as helpers/nonces.sh
./helpers/deploy/bsc-testnet.sh "$@"
./helpers/deploy/soneium-minato-testnet.sh "$@"
./helpers/deploy/opbnb-testnet.sh "$@"
./helpers/deploy/plume-testnet.sh "$@"
./helpers/deploy/base-sepolia.sh "$@"
./helpers/deploy/arbitrum-sepolia.sh "$@"
./helpers/deploy/scroll-sepolia.sh "$@"
./helpers/deploy/sonic-blaze.sh "$@"
./helpers/deploy/amoy.sh "$@"
./helpers/deploy/optimism-sepolia.sh "$@"
./helpers/deploy/sepolia.sh "$@"
./helpers/deploy/fuji.sh "$@"
./helpers/deploy/linea-sepolia.sh "$@"
./helpers/deploy/mantle-sepolia.sh "$@"
./helpers/deploy/zksync-testnet.sh "$@"
./helpers/deploy/celo-sepolia.sh "$@"
./helpers/deploy/hoodi.sh "$@"
./helpers/deploy/monad-testnet.sh "$@"
./helpers/deploy/core-testnet.sh "$@"
./helpers/deploy/rsk-testnet.sh "$@"
./helpers/deploy/bitlayer-testnet.sh "$@"
./helpers/deploy/lens-testnet.sh "$@"
./helpers/deploy/manta-sepolia.sh "$@"
./helpers/deploy/abstract-testnet.sh "$@"
./helpers/deploy/mantra-testnet.sh "$@"
./helpers/deploy/shape-sepolia.sh "$@"
./helpers/deploy/tempo-moderato.sh "$@"
./helpers/deploy/berachain-bepolia.sh "$@"
./helpers/deploy/redbelly-testnet.sh "$@"
