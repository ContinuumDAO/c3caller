#!/bin/bash

# Get the deployer address from the first argument
DEPLOYER=$1
PASSWORD_FILE=$2

# Check if the deployer address is provided
if [ -z "$DEPLOYER" ]; then
    echo "Error: Deployer address is required"
    echo "Usage: $0 <deployer_address> <path_to_password_file>"
    exit 1
fi

# Check if the password file is provided
if [ -z "$PASSWORD_FILE" ]; then
    echo "Error: Password file is required"
    echo "Usage: $0 <deployer_address> <path_to_password_file>"
    exit 1
fi

# Load .env from project root so RPC URL vars are set in this process (not just the parent shell)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Get the nonce for each chain. Use alloy-rs "name" (slug) when in chains.json; else .env.example names.
# https://github.com/alloy-rs/chains/blob/main/assets/chains.json

echo -e "\nNonce for bsc-testnet (97):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url bsc-testnet-rpc-url

echo -e "\nNonce for soneium-minato-testnet (1946):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url soneium-minato-testnet-rpc-url

echo -e "\nNonce for opbnb-testnet (5611):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url opbnb-testnet-rpc-url

echo -e "\nNonce for plume-testnet (98867):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$PLUME_TESTNET_RPC_URL"

echo -e "\nNonce for base-sepolia (84532):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url base-sepolia-rpc-url

echo -e "\nNonce for arbitrum-sepolia (421614):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url arbitrum-sepolia-rpc-url

echo -e "\nNonce for scroll-sepolia (534351):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url scroll-sepolia-rpc-url

echo -e "\nNonce for sonic-blaze (57054):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$SONIC_BLAZE_RPC_URL"

echo -e "\nNonce for amoy (80002):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$AMOY_RPC_URL"

echo -e "\nNonce for optimism-sepolia (11155420):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$OPTIMISM_SEPOLIA_RPC_URL"

echo -e "\nNonce for sepolia (11155111):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url sepolia-rpc-url

echo -e "\nNonce for fuji (43113):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$FUJI_RPC_URL"

echo -e "\nNonce for linea-sepolia (59141):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$LINEA_SEPOLIA_RPC_URL"

echo -e "\nNonce for mantle-sepolia (5003):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$MANTLE_SEPOLIA_RPC_URL"

echo -e "\nNonce for zksync-testnet (300):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$ZKSYNC_TESTNET_RPC_URL"

echo -e "\nNonce for celo-sepolia (11142220):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$CELO_SEPOLIA_RPC_URL"

echo -e "\nNonce for hoodi (560048):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$HOODI_RPC_URL"

echo -e "\nNonce for monad-testnet (10143):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$MONAD_TESTNET_RPC_URL"

echo -e "\nNonce for core-testnet (1114):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$CORE_TESTNET_RPC_URL"

echo -e "\nNonce for rsk-testnet (31):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$RSK_TESTNET_RPC_URL"

echo -e "\nNonce for bitlayer-testnet (200810):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$BITLAYER_TESTNET_RPC_URL"

echo -e "\nNonce for lens-testnet (37111):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$LENS_TESTNET_RPC_URL"

echo -e "\nNonce for manta-sepolia (3441006):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$MANTA_SEPOLIA_RPC_URL"

echo -e "\nNonce for megaeth-testnet (6342):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$MEGAETH_TESTNET_RPC_URL"

echo -e "\nNonce for abstract-testnet (11124):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$ABSTRACT_TESTNET_RPC_URL"

echo -e "\nNonce for mantra-testnet (5887):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$MANTRA_TESTNET_RPC_URL"

echo -e "\nNonce for shape-sepolia (11011):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$SHAPE_SEPOLIA_RPC_URL"

echo -e "\nNonce for tempo-moderato (42431):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$TEMPO_MODERATO_RPC_URL"

echo -e "\nNonce for berachain-bepolia (80069):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$BERACHAIN_BEPOLIA_RPC_URL"

echo -e "\nNonce for kairos-testnet (1001):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$KAIROS_TESTNET_RPC_URL"

echo -e "\nNonce for redbelly-testnet (153):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url "$REDBELLY_TESTNET_RPC_URL"