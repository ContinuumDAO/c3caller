# Contract Verification Commands

This directory contains scripts to verify the C3Caller contracts on Etherscan.

## Prerequisites

1. Set your Etherscan API key as an environment variable:
   ```bash
   export ETHERSCAN_API_KEY="your_api_key_here"
   ```

2. Make sure you have the correct RPC URL set for the network you're verifying on:
   ```bash
   export SEPOLIA_RPC_URL="your_sepolia_rpc_url"
   ```

## Contract Addresses

- **C3UUIDKeeper Implementation**: `0x849a78D9e70D2428c9531981f6F3fcEcB378A78f`
- **C3UUIDKeeper Proxy**: `0xE605C920c942EA4E807a688c554bf83C59D4DB41`
- **C3Caller Implementation**: `0x7A43576Da6A2f738F724747697Cd2fD2424F0C7D`
- **C3Caller Proxy**: `0x9e0625366F7d85A174a59b1a5D2e44F1492a9cBB`

## Verification Commands

### Option 1: Verify All Contracts at Once
```bash
./helpers/verify_contracts.sh
```

### Option 2: Verify Individual Contracts

1. **C3UUIDKeeper Implementation** (no constructor args):
   ```bash
   ./helpers/verify_uuid_impl.sh
   ```

2. **C3Caller Implementation** (no constructor args):
   ```bash
   ./helpers/verify_caller_impl.sh
   ```

3. **C3UUIDKeeper Proxy** (with constructor args):
   ```bash
   ./helpers/verify_uuid_proxy.sh
   ```

4. **C3Caller Proxy** (with constructor args):
   ```bash
   ./helpers/verify_caller_proxy.sh
   ```

## Constructor Arguments Explained

### C3UUIDKeeper Proxy
- **Implementation**: `0x849a78D9e70D2428c9531981f6F3fcEcB378A78f`
- **Init Data**: `abi.encodeWithSignature("initialize()")` = `0x8129fc1c`

### C3Caller Proxy
- **Implementation**: `0x7A43576Da6A2f738F724747697Cd2fD2424F0C7D`
- **Init Data**: `abi.encodeWithSignature("initialize(address)", 0xE605C920c942EA4E807a688c554bf83C59D4DB41)` = `0x8129fc1c000000000000000000000000e605c920c942ea4e807a688c554bf83c59d4db41`

## Manual Commands

If you prefer to run the commands manually:

```bash
# C3UUIDKeeper Implementation
forge verify-contract \
    0x849a78D9e70D2428c9531981f6F3fcEcB378A78f \
    flattened/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol:C3UUIDKeeperUpgradeable \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain sepolia

# C3Caller Implementation
forge verify-contract \
    0x7A43576Da6A2f738F724747697Cd2fD2424F0C7D \
    flattened/upgradeable/C3CallerUpgradeable.sol:C3CallerUpgradeable \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain sepolia

# C3UUIDKeeper Proxy
forge verify-contract \
    0xE605C920c942EA4E807a688c554bf83C59D4DB41 \
    flattened/utils/C3CallerProxy.sol:C3CallerProxy \
    --constructor-args 0x000000000000000000000000849a78d9e70d2428c9531981f6f3fcecb378a78f0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000408129fc1c00000000000000000000000000000000000000000000000000000000000000 \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain sepolia

# C3Caller Proxy
forge verify-contract \
    0x9e0625366F7d85A174a59b1a5D2e44F1492a9cBB \
    flattened/utils/C3CallerProxy.sol:C3CallerProxy \
    --constructor-args 0x0000000000000000000000007a43576da6a2f738f724747697cd2fd2424f0c7d0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004408129fc1c000000000000000000000000e605c920c942ea4e807a688c554bf83c59d4db41000000000000000000000000000000000000000000000000000000000000000 \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain sepolia
```

## Notes

- The implementation contracts have no constructor arguments
- The proxy contracts use the `C3CallerProxy` contract with implementation address and initialization data
- Make sure you're on the correct network (Sepolia in this case)
- The flattened contracts are used for verification to include all dependencies 