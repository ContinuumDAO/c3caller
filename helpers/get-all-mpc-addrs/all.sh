#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Same chain order as helpers/nonces.sh
./helpers/get-all-mpc-addrs/bsc-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/soneium-minato-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/opbnb-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/plume-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/base-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/arbitrum-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/scroll-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/sonic-blaze.sh $C3CALLER
./helpers/get-all-mpc-addrs/amoy.sh $C3CALLER
./helpers/get-all-mpc-addrs/optimism-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/fuji.sh $C3CALLER
./helpers/get-all-mpc-addrs/linea-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/mantle-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/zksync-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/celo-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/hoodi.sh $C3CALLER
./helpers/get-all-mpc-addrs/monad-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/core-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/rsk-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/bitlayer-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/lens-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/manta-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/abstract-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/mantra-testnet.sh $C3CALLER
./helpers/get-all-mpc-addrs/shape-sepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/tempo-moderato.sh $C3CALLER
./helpers/get-all-mpc-addrs/berachain-bepolia.sh $C3CALLER
./helpers/get-all-mpc-addrs/redbelly-testnet.sh $C3CALLER
