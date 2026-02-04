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
./helpers/new-operator/bsc-testnet.sh "$@"
./helpers/new-operator/soneium-minato-testnet.sh "$@"
./helpers/new-operator/opbnb-testnet.sh "$@"
./helpers/new-operator/plume-testnet.sh "$@"
./helpers/new-operator/base-sepolia.sh "$@"
./helpers/new-operator/arbitrum-sepolia.sh "$@"
./helpers/new-operator/scroll-sepolia.sh "$@"
./helpers/new-operator/sonic-blaze.sh "$@"
./helpers/new-operator/amoy.sh "$@"
./helpers/new-operator/optimism-sepolia.sh "$@"
./helpers/new-operator/sepolia.sh "$@"
./helpers/new-operator/fuji.sh "$@"
./helpers/new-operator/linea-sepolia.sh "$@"
./helpers/new-operator/mantle-sepolia.sh "$@"
./helpers/new-operator/zksync-testnet.sh "$@"
./helpers/new-operator/celo-sepolia.sh "$@"
./helpers/new-operator/hoodi.sh "$@"
./helpers/new-operator/monad-testnet.sh "$@"
./helpers/new-operator/core-testnet.sh "$@"
./helpers/new-operator/rsk-testnet.sh "$@"
./helpers/new-operator/bitlayer-testnet.sh "$@"
./helpers/new-operator/lens-testnet.sh "$@"
./helpers/new-operator/manta-sepolia.sh "$@"
./helpers/new-operator/megaeth-testnet.sh "$@"
./helpers/new-operator/abstract-testnet.sh "$@"
./helpers/new-operator/mantra-testnet.sh "$@"
./helpers/new-operator/shape-sepolia.sh "$@"
./helpers/new-operator/tempo-moderato.sh "$@"
./helpers/new-operator/berachain-bepolia.sh "$@"
./helpers/new-operator/kairos-testnet.sh "$@"
./helpers/new-operator/redbelly-testnet.sh "$@"
