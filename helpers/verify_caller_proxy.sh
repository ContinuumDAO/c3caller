#!/bin/bash

# Verify C3Caller proxy
# Constructor args: (implementation, initData)
# implementation: 0x7A43576Da6A2f738F724747697Cd2fD2424F0C7D
# initData: abi.encodeWithSignature("initialize(address)", 0xE605C920c942EA4E807a688c554bf83C59D4DB41)
# = 0x8129fc1c000000000000000000000000e605c920c942ea4e807a688c554bf83c59d4db41
echo "Verifying C3Caller proxy..."
forge verify-contract \
    0x9e0625366F7d85A174a59b1a5D2e44F1492a9cBB \
    flattened/utils/C3CallerProxy.sol:C3CallerProxy \
    --constructor-args c4d66de8000000000000000000000000e605c920c942ea4e807a688c554bf83c59d4db4100000000000000000000000000000000000000000000000000000000 \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain $1