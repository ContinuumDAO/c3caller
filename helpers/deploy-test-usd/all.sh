#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Parse --account and --password-file (or positional ACCOUNT PASSWORD_FILE)
ACCOUNT=""
PASSWORD_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --account) ACCOUNT="$2"; shift 2 ;;
        --password-file) PASSWORD_FILE="$2"; shift 2 ;;
        *) ACCOUNT="${ACCOUNT:-$1}"; PASSWORD_FILE="${PASSWORD_FILE:-$2}"; shift 2; break ;;
    esac
done
if [[ -z "$ACCOUNT" || -z "$PASSWORD_FILE" ]]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "   or: $0 --account <ACCOUNT> --password-file <PASSWORD_FILE>"
    echo "Example: $0 a55e7 ~/.evm-keys/.auth.a55e7"
    exit 1
fi

# Same chain order as helpers/nonces.sh (and .env). Uncomment to run; add script if missing.
# ./helpers/deploy-test-usd/bsc-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/soneium-minato-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/opbnb-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/plume-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/base-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/arbitrum-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/scroll-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/sonic-blaze.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/amoy.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/optimism-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/fuji.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/linea-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/mantle-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/zksync-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/celo-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/hoodi.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/monad-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/core-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/rsk-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/bitlayer-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/lens-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/manta-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/abstract-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/mantra-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/shape-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/tempo-moderato.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/berachain-bepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
# ./helpers/deploy-test-usd/redbelly-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
# Chains below match .env/nonces.sh order
./helpers/deploy-test-usd/cronos-zkevm-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/arc-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/boba-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/citrea-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/metis-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/mode-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/ink-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/world-chain-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/polynomial-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/bob-sepolia.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/kiteai-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"
./helpers/deploy-test-usd/lightlink-pegasus-testnet.sh "$ACCOUNT" "$PASSWORD_FILE"

echo "Fee token addresses have been saved to deployments.toml and fee-token.json by each chain script."
