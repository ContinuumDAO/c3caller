#!/bin/bash

# Verify C3UUIDKeeper proxy
# Constructor args: (implementation, initData)
# implementation: 0x849a78D9e70D2428c9531981f6F3fcEcB378A78f
# initData: abi.encodeWithSignature("initialize()") = 0x8129fc1c
echo "Verifying C3UUIDKeeper proxy..."
forge verify-contract \
    0xE605C920c942EA4E807a688c554bf83C59D4DB41 \
    flattened/utils/C3CallerProxy.sol:C3CallerProxy \
    --constructor-args 000000000000000000000000849a78d9e70d2428c9531981f6f3fcecb378a78f000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000048129fc1c00000000000000000000000000000000000000000000000000000000 \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain $1