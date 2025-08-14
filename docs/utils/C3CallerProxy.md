# C3CallerProxy

## Overview

C3CallerProxy is a proxy contract for C3Caller implementation using ERC1967 standard. This contract acts as a proxy to the actual C3Caller implementation, allowing for upgradeable functionality while maintaining the same interface.

The proxy delegates all calls to the implementation contract and provides a way to retrieve the current implementation address.

**Note:** This contract enables upgradeable C3Caller functionality

## Contract Details

- **Contract Name:** `C3CallerProxy`
- **Inherits:** `ERC1967Proxy`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## Constructor

### `constructor(address _implementation, bytes memory _data)`
Initializes the C3CallerProxy contract.

**Parameters:**
- `_implementation` (address): Address of the implementation contract
- `_data` (bytes): Initialization data for the implementation contract

**Notes:**
- Calls the ERC1967Proxy constructor

## External Functions

### `getImplementation()`
Get the current implementation address.

**Returns:**
- `address`: The address of the current implementation contract

## Receive Function

### `receive()`
Fallback function to receive ETH.

**Notes:**
- Allows the contract to receive ETH transfers
- External payable function

## Usage Examples

### Deploying the Proxy
```solidity
// Deploy implementation contract
C3Caller implementation = new C3Caller(uuidKeeperAddress);

// Prepare initialization data
bytes memory initData = abi.encodeWithSelector(
    C3Caller.initialize.selector,
    param1,
    param2
);

// Deploy proxy contract
C3CallerProxy proxy = new C3CallerProxy(
    address(implementation),
    initData
);
```

### Getting Implementation Address
```solidity
// Get current implementation
address currentImpl = proxy.getImplementation();

// Check if implementation has changed
if (currentImpl != expectedImpl) {
    // Implementation has been upgraded
}
```

## Security Considerations

1. **Upgradeable Design**: The proxy allows for implementation upgrades while maintaining the same interface
2. **ERC1967 Standard**: Uses the standard ERC1967 proxy pattern for security and compatibility
3. **ETH Reception**: Can receive ETH transfers through the receive function

## Dependencies

- `@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol`
- `@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol`
