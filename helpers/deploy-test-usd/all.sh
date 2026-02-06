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
./helpers/deploy-test-usd/bsc-testnet.sh "$@"
./helpers/deploy-test-usd/soneium-minato-testnet.sh "$@"
./helpers/deploy-test-usd/opbnb-testnet.sh "$@"
./helpers/deploy-test-usd/plume-testnet.sh "$@"
./helpers/deploy-test-usd/base-sepolia.sh "$@"
./helpers/deploy-test-usd/arbitrum-sepolia.sh "$@"
./helpers/deploy-test-usd/scroll-sepolia.sh "$@"
./helpers/deploy-test-usd/sonic-blaze.sh "$@"
./helpers/deploy-test-usd/amoy.sh "$@"
./helpers/deploy-test-usd/optimism-sepolia.sh "$@"
./helpers/deploy-test-usd/sepolia.sh "$@"
./helpers/deploy-test-usd/fuji.sh "$@"
./helpers/deploy-test-usd/linea-sepolia.sh "$@"
./helpers/deploy-test-usd/mantle-sepolia.sh "$@"
./helpers/deploy-test-usd/zksync-testnet.sh "$@"
./helpers/deploy-test-usd/celo-sepolia.sh "$@"
./helpers/deploy-test-usd/hoodi.sh "$@"
./helpers/deploy-test-usd/monad-testnet.sh "$@"
./helpers/deploy-test-usd/core-testnet.sh "$@"
./helpers/deploy-test-usd/rsk-testnet.sh "$@"
./helpers/deploy-test-usd/bitlayer-testnet.sh "$@"
./helpers/deploy-test-usd/lens-testnet.sh "$@"
./helpers/deploy-test-usd/manta-sepolia.sh "$@"
./helpers/deploy-test-usd/abstract-testnet.sh "$@"
./helpers/deploy-test-usd/mantra-testnet.sh "$@"
./helpers/deploy-test-usd/shape-sepolia.sh "$@"
./helpers/deploy-test-usd/tempo-moderato.sh "$@"
./helpers/deploy-test-usd/berachain-bepolia.sh "$@"
./helpers/deploy-test-usd/redbelly-testnet.sh "$@"
