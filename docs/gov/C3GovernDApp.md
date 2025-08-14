# C3GovernDApp

## Overview

C3GovernDApp is an abstract contract for governance DApp functionality in the C3 protocol. This contract extends C3CallerDApp to provide governance-specific features including delayed governance changes and transaction sender management.

### Key Features

- Delayed governance address changes
- Transaction sender management
- Governance-driven cross-chain operations
- Fallback mechanism for failed operations

**Note:** This contract provides governance functionality for DApps

## Contract Details

- **Contract Name:** `C3GovernDApp`
- **Type:** Abstract Contract
- **Implements:** `IC3GovernDApp`
- **Inherits:** `C3CallerDApp`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## State Variables

### `delay`
```solidity
uint256 public delay
```
Delay period for governance changes (default: 2 days).

### `_oldGov`
```solidity
address internal _oldGov
```
The old governance address.

### `_newGov`
```solidity
address internal _newGov
```
The new governance address.

### `_newGovEffectiveTime`
```solidity
uint256 internal _newGovEffectiveTime
```
The effective time for the new governance address.

### `_txSenders`
```solidity
mapping(address => bool) internal _txSenders
```
Mapping of transaction sender addresses to their validity.

## Constructor

### `constructor(address _gov, address _c3callerProxy, address _txSender, uint256 _dappID)`
Initializes the C3GovernDApp contract.

**Parameters:**
- `_gov` (address): The initial governance address
- `_c3callerProxy` (address): The C3Caller proxy address
- `_txSender` (address): The initial transaction sender address
- `_dappID` (uint256): The DApp identifier

**Notes:**
- Sets default delay to 2 days
- Initializes governance addresses and effective time
- Adds the initial transaction sender

## Modifiers

### `onlyGov`
Restricts access to governance or C3Caller.

**Notes:**
- Reverts if the caller is neither governor nor C3Caller

## External Functions

### `txSenders(address sender)`
Check if an address is a valid transaction sender.

**Parameters:**
- `sender` (address): The address to check

**Returns:**
- `bool`: True if the address is a valid transaction sender

### `gov()`
Get the current governance address.

**Returns:**
- `address`: The current governance address (new or old based on effective time)

### `changeGov(address newGov_)`
Change the governance address with delay.

**Parameters:**
- `newGov_` (address): The new governance address

**Modifiers:**
- `onlyGov`

**Notes:**
- Only governance or C3Caller can call this function
- Reverts if the new governance address is zero

### `setDelay(uint256 _delay)`
Set the delay period for governance changes.

**Parameters:**
- `_delay` (uint256): The new delay period in seconds

**Modifiers:**
- `onlyGov`

**Notes:**
- Only governance or C3Caller can call this function

### `addTxSender(address _txSender)`
Add a transaction sender address.

**Parameters:**
- `_txSender` (address): The transaction sender address to add

**Modifiers:**
- `onlyGov`

**Notes:**
- Only governance or C3Caller can call this function

### `disableTxSender(address _txSender)`
Disable a transaction sender address.

**Parameters:**
- `_txSender` (address): The transaction sender address to disable

**Modifiers:**
- `onlyGov`

**Notes:**
- Only governance or C3Caller can call this function

### `doGov(string memory _to, string memory _toChainID, bytes memory _data)`
Execute governance operation on a single target.

**Parameters:**
- `_to` (string): The target address on the destination chain
- `_toChainID` (string): The destination chain identifier
- `_data` (bytes): The calldata to execute

**Modifiers:**
- `onlyGov`

**Notes:**
- Only governance or C3Caller can call this function

### `doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data)`
Execute governance operation on multiple targets.

**Parameters:**
- `_targets` (string[]): Array of target addresses on destination chains
- `_toChainIDs` (string[]): Array of destination chain identifiers
- `_data` (bytes): The calldata to execute

**Modifiers:**
- `onlyGov`

**Notes:**
- Only governance or C3Caller can call this function
- Reverts if the arrays have different lengths

### `isValidSender(address _txSender)`
Check if an address is a valid sender for this DApp.

**Parameters:**
- `_txSender` (address): The address to check

**Returns:**
- `bool`: True if the address is a valid sender

**Notes:**
- Overrides the function from IC3CallerDApp and C3CallerDApp

## Events

### `LogChangeGov`
Emitted when the governance address is changed.

```solidity
event LogChangeGov(
    address indexed _oldGov,
    address indexed _newGov,
    uint256 indexed _effectiveTime,
    uint256 _chainID
);
```

### `LogTxSender`
Emitted when a transaction sender is added or disabled.

```solidity
event LogTxSender(address indexed _txSender, bool _valid);
```

## Errors

### `C3GovernDApp_OnlyAuthorized`
Thrown when an unauthorized address attempts to perform an operation.

```solidity
error C3GovernDApp_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
```

### `C3GovernDApp_IsZeroAddress`
Thrown when a required address parameter is zero.

```solidity
error C3GovernDApp_IsZeroAddress(C3ErrorParam);
```

### `C3GovernDApp_LengthMismatch`
Thrown when two arrays have mismatched lengths.

```solidity
error C3GovernDApp_LengthMismatch(C3ErrorParam, C3ErrorParam);
```

## Usage Examples

### Governance Change with Delay
```solidity
// Change governance address (takes effect after delay)
governDApp.changeGov(newGovernanceAddress);

// Check current governance address
address currentGov = governDApp.gov();

// Set custom delay period
governDApp.setDelay(7 days); // 7 days delay
```

### Transaction Sender Management
```solidity
// Add a new transaction sender
governDApp.addTxSender(newTxSenderAddress);

// Check if address is valid sender
bool isValid = governDApp.txSenders(someAddress);

// Disable a transaction sender
governDApp.disableTxSender(oldTxSenderAddress);
```

### Cross-Chain Governance Operations
```solidity
// Execute governance operation on single target
governDApp.doGov(
    "0x1234567890123456789012345678901234567890", // target
    "1", // chainId
    abi.encodeWithSelector(SomeFunction.selector, param1, param2) // data
);

// Execute governance operation on multiple targets
string[] memory targets = new string[](2);
targets[0] = "0x1234567890123456789012345678901234567890";
targets[1] = "0x0987654321098765432109876543210987654321";

string[] memory chainIDs = new string[](2);
chainIDs[0] = "1";
chainIDs[1] = "137";

governDApp.doGovBroadcast(
    targets,
    chainIDs,
    abi.encodeWithSelector(SomeFunction.selector, param1, param2)
);
```

## Security Considerations

1. **Delayed Governance Changes**: Governance changes have a delay period to prevent immediate takeovers
2. **Access Control**: Strict access control through modifiers ensures only authorized addresses can perform operations
3. **Transaction Sender Management**: Validates transaction senders for cross-chain operations
4. **Effective Time Tracking**: Tracks when governance changes take effect

## Dependencies

- `@openzeppelin/contracts/utils/Address.sol`
- `@openzeppelin/contracts/utils/Strings.sol`
- `C3CallerDApp.sol`
- `IC3CallerDApp.sol`
- `C3ErrorParam` from `C3CallerUtils.sol`
- `IC3GovernDApp.sol`
