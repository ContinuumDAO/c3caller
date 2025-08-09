#!/bin/bash

# Verify C3Caller implementation (no constructor args)
echo "Verifying C3Caller implementation..."
forge verify-contract \
    0x7A43576Da6A2f738F724747697Cd2fD2424F0C7D \
    flattened/upgradeable/C3CallerUpgradeable.sol:C3CallerUpgradeable \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain $1