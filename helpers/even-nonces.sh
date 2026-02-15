#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../" && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Check if required arguments are provided
if [ $# -lt 3 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE> <NONCE>"
    echo "Example: $0 0x1234... /path/to/password.txt 10"
    exit 1
fi

ACCOUNT=$1
PASSWORD_FILE=$2
NONCE=$3

# Check if the account is provided
if [ -z "$ACCOUNT" ]; then
    echo "Error: Account is required"
    echo "Usage: $0 <account> <password_file>"
    exit 1
fi

# Check if the password file is provided
if [ -z "$PASSWORD_FILE" ]; then
    echo "Error: Password file is required"
    echo "Usage: $0 <account> <password_file>"
    exit 1
fi

# Check if the account is valid
if ! cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE > /dev/null 2>&1; then
    echo "Error: Invalid account"
    echo "Usage: $0 <account> <password_file>"
    exit 1
fi


if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $BSC_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for BSC Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $BSC_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $SONEIUM_MINATO_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Soneium Minato Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $SONEIUM_MINATO_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $OPBNB_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for OPBNB Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $OPBNB_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $PLUME_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Plume Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $PLUME_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $BASE_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Base Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $BASE_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $ARBITRUM_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Arbitrum Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $SCROLL_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Scroll Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $SCROLL_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $SONIC_BLAZE_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Sonic Blaze"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $SONIC_BLAZE_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $AMOY_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Amoy"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $AMOY_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $OPTIMISM_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Optimism Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $FUJI_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Fuji"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $FUJI_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $LINEA_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Linea Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $LINEA_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $MANTLE_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Mantle Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $MANTLE_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $ZKSYNC_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for ZKSync Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $ZKSYNC_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $CELO_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Celo Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $CELO_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $HOODI_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Hoodi"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $HOODI_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $MONAD_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Monad Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $MONAD_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $MANTA_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Manta Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $MANTA_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $ABSTRACT_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Abstract Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $ABSTRACT_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $MANTRA_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Mantra Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $MANTRA_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $SHAPE_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Shape Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $SHAPE_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $BERACHAIN_BEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Berachain Be"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $BERACHAIN_BEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $CORE_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Core Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $CORE_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $RSK_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for RSK Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $RSK_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $BITLAYER_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Bitlayer Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $BITLAYER_TESTNET_RPC_URL --legacy
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $LENS_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Lens Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $LENS_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $CRONOS_ZKEVM_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Cronos ZK EVM Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $CRONOS_ZKEVM_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $ARC_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for ARC Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $ARC_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $BOBA_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Boba Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $BOBA_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $CITREA_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Citrea Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $CITREA_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $METIS_SEPOLIA_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Metis Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $METIS_SEPOLIA_TESTNET_RPC_URL --legacy
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $MODE_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Mode Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $MODE_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $INK_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Ink Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $INK_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $WORLD_CHAIN_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for World Chain Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $WORLD_CHAIN_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $POLYNOMIAL_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Polynomial Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $POLYNOMIAL_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $BOB_SEPOLIA_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Bob Sepolia"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $BOB_SEPOLIA_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $KITEAI_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Kiteai Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $KITEAI_TESTNET_RPC_URL
fi
if [ $(($NONCE - $(cast nonce $(cast wallet address --account $ACCOUNT --password-file $PASSWORD_FILE) --rpc-url $LIGHTLINK_PEGASUS_TESTNET_RPC_URL))) -gt 0 ]; then
echo "Setting nonce for Lightlink Pegasus Testnet"
cast send --value 10 0xe62Ab4D111f968660C6B2188046F9B9bA53C4Bae --account $ACCOUNT --password-file $PASSWORD_FILE --rpc-url $LIGHTLINK_PEGASUS_TESTNET_RPC_URL --legacy
fi