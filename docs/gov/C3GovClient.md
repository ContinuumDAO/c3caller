# C3GovClient

Base contract for governance client functionality in the C3 protocol. This contract provides governance and operator management capabilities that can be inherited by other contracts in the C3 ecosystem. The key difference between this contract and C3GovernDApp is that this contract does not contain a DApp ID, as it is designed to provide governance functionality without cross-chain functionality.

Examples of contracts that implement this contract are C3Caller, C3UUIDKeeper and C3DAppManager. These are protocol contracts and therefore do not need to be a C3GovernDApp.

## Key Features

- Governance address management with pending changes
- Operator management (add/remove operators)
- Access control modifiers for governance and operators
- Event emission for governance changes

## Constructor

```solidity
constructor(address _gov)
```

**Parameters:**
- `_gov`: The initial governance address

## State Variables

### gov
```solidity
address public gov
```
The current governance address

### pendingGov
```solidity
address public pendingGov
```
The pending governance address (for two-step governance changes)

### isOperator
```solidity
mapping(address => bool) public isOperator
```
Mapping of addresses to operator status

### operators
```solidity
address[] public operators
```
Array of all operator addresses

## Modifiers

### onlyGov
```solidity
modifier onlyGov()
```
Modifier to restrict access to governance only.

**Dev:** Reverts if the caller is not the governance address

### onlyOperator
```solidity
modifier onlyOperator()
```
Modifier to restrict access to governance or operators.

**Dev:** Reverts if the caller is neither governance address nor an operator

## Functions

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

This contract provides the foundation for governance functionality