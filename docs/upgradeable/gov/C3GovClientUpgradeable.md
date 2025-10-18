# C3GovClientUpgradeable

Upgradeable base contract for governance client functionality in the C3 protocol. This contract provides governance and operator management capabilities that can be inherited by other contracts in the C3 ecosystem. The key difference between this contract and C3GovernDApp is that this contract does not contain a DApp ID, as it is designed to provide governance functionality without cross-chain functionality. It features upgradeable storage using the ERC-7201 storage pattern.

Examples of contracts that implement this contract are C3Caller, C3UUIDKeeper and C3DAppManager. These are protocol contracts and therefore do not need to be a C3GovernDApp.

## Key Features

- Governance address management with pending changes
- Operator management (add/remove operators)
- Access control modifiers for governance and operators
- Event emission for governance changes
- Upgradeable storage using ERC-7201 pattern

## Storage Structure

### C3GovClientStorage
```solidity
struct C3GovClientStorage {
    /// @notice The current governance address
    address gov;
    /// @notice The pending governance address (for two-step governance changes)
    address pendingGov;
    /// @notice Mapping of addresses to operator status
    mapping(address => bool) isOperator;
    /// @notice Array of all operator addresses
    address[] operators;
}
```

Storage struct for C3GovClient using ERC-7201 storage pattern.

## Functions

### gov
```solidity
function gov() public view returns (address)
```
Get the current governance address.

**Returns:**
- `address`: The current governance address

### pendingGov
```solidity
function pendingGov() public view returns (address)
```
Get the pending governance address.

**Returns:**
- `address`: The pending governance address

### isOperator
```solidity
function isOperator(address _op) public view returns (bool)
```
Check if an address is an operator.

**Parameters:**
- `_op`: The address to check

**Returns:**
- `bool`: True if the address is an operator

### operators
```solidity
function operators(uint256 _index) public view returns (address)
```
Get operator address by index.

**Parameters:**
- `_index`: The index of the operator

**Returns:**
- `address`: The operator address at the specified index

### changeGov
```solidity
function changeGov(address _gov) external onlyGov
```
Change the governance address (two-step process).

**Parameters:**
- `_gov`: The new governance address

**Dev:** Only the current governance address can call this function

### applyGov
```solidity
function applyGov() external
```
Apply the pending governance change.

**Dev:** Reverts if there is no pending governance address. Anyone can call this function to finalize the governance change

### addOperator
```solidity
function addOperator(address _op) external onlyGov
```
Add an operator.

**Parameters:**
- `_op`: The address to add as an operator

**Dev:** Only the governance address can call this function

### revokeOperator
```solidity
function revokeOperator(address _op) external onlyGov
```
Revoke operator status from an address.

**Parameters:**
- `_op`: The address from which to revoke operator status

**Dev:** Reverts if the address is already not an operator. Only the governance address can call this function

### getAllOperators
```solidity
function getAllOperators() external view returns (address[] memory)
```
Get all operator addresses.

**Returns:**
- `address[]`: Array of all operator addresses

## Internal Functions

### _getC3GovClientStorage
```solidity
function _getC3GovClientStorage() private pure returns (C3GovClientStorage storage $)
```
Get the storage struct for C3GovClient.

**Returns:**
- `C3GovClientStorage`: The storage struct

### __C3GovClient_init
```solidity
function __C3GovClient_init(address _gov) internal onlyInitializing
```
Internal initializer for the upgradeable C3GovClient contract.

**Parameters:**
- `_gov`: The initial governance address

## Modifiers

### onlyGov
```solidity
modifier onlyGov()
```
Modifier to restrict access to governance only.

**Dev:** Reverts if the caller is not the governor

### onlyOperator
```solidity
modifier onlyOperator()
```
Modifier to restrict access to governance or operators.

**Dev:** Reverts if the caller is neither governor nor an operator

## Events

### ApplyGov
```solidity
event ApplyGov(address oldGov, address newGov, uint256 timestamp)
```

### ChangeGov
```solidity
event ChangeGov(address oldGov, address newGov, uint256 timestamp)
```

### AddOperator
```solidity
event AddOperator(address operator)
```

## Errors

### C3GovClient_OnlyAuthorized
```solidity
error C3GovClient_OnlyAuthorized(C3ErrorParam, C3ErrorParam)
```

### C3GovClient_IsZeroAddress
```solidity
error C3GovClient_IsZeroAddress(C3ErrorParam)
```

### C3GovClient_AlreadyOperator
```solidity
error C3GovClient_AlreadyOperator(address)
```

### C3GovClient_IsNotOperator
```solidity
error C3GovClient_IsNotOperator(address)
```

## Author

@potti ContinuumDAO

## Dev

This contract provides the foundation for upgradeable governance functionality