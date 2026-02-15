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

# 20% gas estimate multiplier for broadcast (override with INIT_C3DAPP_GAS_ESTIMATE_MULTIPLIER if needed).
export INIT_C3DAPP_GAS_ESTIMATE_MULTIPLIER=${INIT_C3DAPP_GAS_ESTIMATE_MULTIPLIER:-120}

# Same chain order as helpers/deploy/all.sh, excluding redbelly-testnet and pharos-atlantic-testnet
# ./helpers/init-c3dapp/bsc-testnet.sh "$@"
# ./helpers/init-c3dapp/soneium-minato-testnet.sh "$@"
# ./helpers/init-c3dapp/opbnb-testnet.sh "$@"
# ./helpers/init-c3dapp/plume-testnet.sh "$@"
# ./helpers/init-c3dapp/base-sepolia.sh "$@"
# ./helpers/init-c3dapp/arbitrum-sepolia.sh "$@"
# ./helpers/init-c3dapp/scroll-sepolia.sh "$@"
# ./helpers/init-c3dapp/sonic-blaze.sh "$@"
# ./helpers/init-c3dapp/amoy.sh "$@"
# ./helpers/init-c3dapp/optimism-sepolia.sh "$@"
# ./helpers/init-c3dapp/sepolia.sh "$@"
# ./helpers/init-c3dapp/fuji.sh "$@"
# ./helpers/init-c3dapp/linea-sepolia.sh "$@"
# ./helpers/init-c3dapp/mantle-sepolia.sh "$@"
# ./helpers/init-c3dapp/zksync-testnet.sh "$@"
./helpers/init-c3dapp/celo-sepolia.sh "$@"
./helpers/init-c3dapp/hoodi.sh "$@"
./helpers/init-c3dapp/monad-testnet.sh "$@"
./helpers/init-c3dapp/core-testnet.sh "$@"
./helpers/init-c3dapp/rsk-testnet.sh "$@"
./helpers/init-c3dapp/bitlayer-testnet.sh "$@"
./helpers/init-c3dapp/lens-testnet.sh "$@"
./helpers/init-c3dapp/manta-sepolia.sh "$@"
./helpers/init-c3dapp/abstract-testnet.sh "$@"
./helpers/init-c3dapp/mantra-testnet.sh "$@"
./helpers/init-c3dapp/shape-sepolia.sh "$@"
#./helpers/init-c3dapp/tempo-moderato.sh "$@"
./helpers/init-c3dapp/berachain-bepolia.sh "$@"
./helpers/init-c3dapp/cronos-zkevm-testnet.sh "$@"
./helpers/init-c3dapp/arc-testnet.sh "$@"
./helpers/init-c3dapp/boba-sepolia.sh "$@"
./helpers/init-c3dapp/citrea-testnet.sh "$@"
./helpers/init-c3dapp/metis-sepolia.sh "$@"
./helpers/init-c3dapp/mode-testnet.sh "$@"
./helpers/init-c3dapp/ink-sepolia.sh "$@"
./helpers/init-c3dapp/world-chain-sepolia.sh "$@"
./helpers/init-c3dapp/polynomial-sepolia.sh "$@"
./helpers/init-c3dapp/bob-sepolia.sh "$@"
./helpers/init-c3dapp/kiteai-testnet.sh "$@"
./helpers/init-c3dapp/lightlink-pegasus-testnet.sh "$@"
