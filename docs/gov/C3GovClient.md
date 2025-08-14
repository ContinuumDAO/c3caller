# C3GovClient

## Overview

C3GovClient is a base contract for governance client functionality in the C3 protocol. This contract provides governance and operator management capabilities that can be inherited by other contracts in the C3 ecosystem.

### Key Features

- Governance address management with pending changes
- Operator management (add/remove operators)
- Access control modifiers for governance and operators
- Event emission for governance changes

**Note:** This contract provides the foundation for governance functionality

## Contract Details

- **Contract Name:** `C3GovClient`
- **Implements:** `IC3GovClient`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## State Variables

### `gov`
```solidity
address public gov
```
The current governance address.

### `pendingGov`
```solidity
address public pendingGov
```
The pending governance address (for two-step governance changes).

### `isOperator`
```solidity
mapping(address => bool) public isOperator
```
Mapping of addresses to operator status.

### `operators`
```solidity
address[] public operators
```
Array of all operator addresses.

## Constructor

### `constructor(address _gov)`
Initializes the C3GovClient contract.

**Parameters:**
- `_gov` (address): The initial governance address

**Notes:**
- Sets the initial governor and emits an ApplyGov event

## Modifiers

### `onlyGov`
Restricts access to governance only.

**Notes:**
- Reverts if the caller is not the governor

### `onlyOperator`
Restricts access to governance or operators.

**Notes:**
- Reverts if the caller is neither governor nor an operator

## External Functions

### `changeGov(address _gov)`
Change the governance address (two-step process).

**Parameters:**
- `_gov` (address): The new governance address

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the current governor can call this function
- Sets the pending governor address

### `applyGov()`
Apply the pending governance change.

**Notes:**
- Anyone can call this function to finalize the governance change
- Reverts if there is no pending governance address

### `addOperator(address _op)`
Add an operator (governance only).

**Parameters:**
- `_op` (address): The address to add as an operator

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function

### `getAllOperators()`
Get all operator addresses.

**Returns:**
- `address[]`: Array of all operator addresses

### `revokeOperator(address _op)`
Revoke operator status from an address (governance only).

**Parameters:**
- `_op` (address): The address to revoke operator status from

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function
- Reverts if the address is not an operator

## Internal Functions

### `_addOperator(address _op)`
Internal function to add an operator.

**Parameters:**
- `_op` (address): The address to add as an operator

**Notes:**
- Reverts if the address is zero or already an operator
- Adds the address to the operators array and sets the mapping

## Events

### `ChangeGov`
Emitted when the governor is changed.

```solidity
event ChangeGov(address indexed oldGov, address indexed newGov, uint256 timestamp);
```

### `ApplyGov`
Emitted when the governor change is applied.

```solidity
event ApplyGov(address indexed oldGov, address indexed newGov, uint256 timestamp);
```

### `AddOperator`
Emitted when an operator is added.

```solidity
event AddOperator(address indexed op);
```

## Errors

### `C3GovClient_OnlyAuthorized`
Thrown when an unauthorized address attempts to perform an operation.

```solidity
error C3GovClient_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
```

### `C3GovClient_IsZeroAddress`
Thrown when a required address parameter is zero.

```solidity
error C3GovClient_IsZeroAddress(C3ErrorParam);
```

### `C3GovClient_AlreadyOperator`
Thrown when attempting to add an address that is already an operator.

```solidity
error C3GovClient_AlreadyOperator(address);
```

### `C3GovClient_IsNotOperator`
Thrown when attempting to revoke an address that is not an operator.

```solidity
error C3GovClient_IsNotOperator(address);
```

## Usage Examples

### Governance Change Process
```solidity
// Step 1: Current governor initiates change
govClient.changeGov(newGovernorAddress);

// Step 2: New governor applies the change
govClient.applyGov();
```

### Operator Management
```solidity
// Add an operator (governance only)
govClient.addOperator(operatorAddress);

// Check if an address is an operator
bool isOp = govClient.isOperator(operatorAddress);

// Get all operators
address[] memory allOperators = govClient.getAllOperators();

// Revoke an operator (governance only)
govClient.revokeOperator(operatorAddress);
```

### Access Control in Derived Contracts
```solidity
contract MyContract is C3GovClient {
    constructor(address _gov) C3GovClient(_gov) {}

    function adminFunction() external onlyGov {
        // Only governor can call this
    }

    function operatorFunction() external onlyOperator {
        // Governor or operators can call this
    }
}
```

## Security Considerations

1. **Two-Step Governance Changes**: Governance changes require two steps to prevent accidental transfers
2. **Access Control**: Strict access control through modifiers ensures only authorized addresses can perform operations
3. **Operator Management**: Operators can be added and revoked by the governor
4. **Event Emission**: All governance changes are logged through events for transparency

## Dependencies

- `C3ErrorParam` from `C3CallerUtils.sol`
- `IC3GovClient.sol`
