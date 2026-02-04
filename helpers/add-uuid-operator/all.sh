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
./helpers/add-uuid-operator/bsc-testnet.sh "$@"
./helpers/add-uuid-operator/soneium-minato-testnet.sh "$@"
./helpers/add-uuid-operator/opbnb-testnet.sh "$@"
./helpers/add-uuid-operator/plume-testnet.sh "$@"
./helpers/add-uuid-operator/base-sepolia.sh "$@"
./helpers/add-uuid-operator/arbitrum-sepolia.sh "$@"
./helpers/add-uuid-operator/scroll-sepolia.sh "$@"
./helpers/add-uuid-operator/sonic-blaze.sh "$@"
./helpers/add-uuid-operator/amoy.sh "$@"
./helpers/add-uuid-operator/optimism-sepolia.sh "$@"
./helpers/add-uuid-operator/sepolia.sh "$@"
./helpers/add-uuid-operator/fuji.sh "$@"
./helpers/add-uuid-operator/linea-sepolia.sh "$@"
./helpers/add-uuid-operator/mantle-sepolia.sh "$@"
./helpers/add-uuid-operator/zksync-testnet.sh "$@"
./helpers/add-uuid-operator/celo-sepolia.sh "$@"
./helpers/add-uuid-operator/hoodi.sh "$@"
./helpers/add-uuid-operator/monad-testnet.sh "$@"
./helpers/add-uuid-operator/core-testnet.sh "$@"
./helpers/add-uuid-operator/rsk-testnet.sh "$@"
./helpers/add-uuid-operator/bitlayer-testnet.sh "$@"
./helpers/add-uuid-operator/lens-testnet.sh "$@"
./helpers/add-uuid-operator/manta-sepolia.sh "$@"
./helpers/add-uuid-operator/megaeth-testnet.sh "$@"
./helpers/add-uuid-operator/abstract-testnet.sh "$@"
./helpers/add-uuid-operator/mantra-testnet.sh "$@"
./helpers/add-uuid-operator/shape-sepolia.sh "$@"
./helpers/add-uuid-operator/tempo-moderato.sh "$@"
./helpers/add-uuid-operator/berachain-bepolia.sh "$@"
./helpers/add-uuid-operator/kairos-testnet.sh "$@"
./helpers/add-uuid-operator/redbelly-testnet.sh "$@"
