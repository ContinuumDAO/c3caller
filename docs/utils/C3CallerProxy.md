# C3CallerProxy

Proxy contract for C3 protocol contracts using the ERC1967 standard. This contract acts as a proxy to the implementation, allowing for upgradeable functionality while maintaining the same interface.

The proxy delegates all calls to the implementation contract and provides a way to retrieve the current implementation address.

## Constructor

```solidity
constructor(address _implementation, bytes memory _data)
```

**Parameters:**
- `_implementation`: Address of the implementation contract
- `_data`: Initialization data for the implementation contract

## Functions

### getImplementation
```solidity
function getImplementation() external view returns (address)
```
Get the current implementation address.

**Returns:**
- `address`: The address of the current implementation contract

### receive
```solidity
receive() external payable
```
Fallback function to direct calls to the implementation.

**Dev:** Allows the transfer of ETH

## Author

@potti ContinuumDAO

## Dev

This contract enables upgradeability