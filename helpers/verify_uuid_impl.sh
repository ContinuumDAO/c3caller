#!/bin/bash

# Verify C3UUIDKeeper implementation (no constructor args)
echo "Verifying C3UUIDKeeper implementation..."
forge verify-contract \
    0x849a78D9e70D2428c9531981f6F3fcEcB378A78f \
    flattened/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol:C3UUIDKeeperUpgradeable \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain $1