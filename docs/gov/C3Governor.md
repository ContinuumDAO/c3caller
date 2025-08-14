# C3Governor

## Overview

C3Governor is a governance contract for cross-chain proposal management in the C3 protocol. This contract extends C3GovernDApp to provide proposal-based governance functionality for cross-chain operations.

### Key Features

- Proposal creation and management
- Cross-chain proposal execution
- Proposal data storage and retrieval
- Failed proposal handling and retry mechanisms

**Note:** This contract enables governance-driven cross-chain operations

## Contract Details

- **Contract Name:** `C3Governor`
- **Implements:** `IC3Governor`
- **Inherits:** `C3GovernDApp`
- **Author:** @potti and @selqui ContinuumDAO
- **License:** BSL-1.1

## State Variables

### `_proposal`
```solidity
mapping(bytes32 => Proposal) private _proposal
```
Mapping of proposal nonce to proposal data.

### `proposalId`
```solidity
bytes32 public proposalId
```
Current proposal identifier.

## Constructor

### `constructor(address _gov, address _c3CallerProxy, address _txSender, uint256 _dappID)`
Initializes the C3Governor contract.

**Parameters:**
- `_gov` (address): The governance address
- `_c3CallerProxy` (address): The C3Caller proxy address
- `_txSender` (address): The transaction sender address
- `_dappID` (uint256): The DApp identifier

**Notes:**
- Calls the C3GovernDApp constructor

## External Functions

### `sendParams(bytes memory _data, bytes32 _nonce)`
Send a single parameter for governance proposal.

**Parameters:**
- `_data` (bytes): The proposal data
- `_nonce` (bytes32): The proposal nonce

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function
- Reverts if the data is empty

### `sendMultiParams(bytes[] memory _data, bytes32 _nonce)`
Send multiple parameters for governance proposal.

**Parameters:**
- `_data` (bytes[]): Array of proposal data
- `_nonce` (bytes32): The proposal nonce

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function
- Reverts if the data array is empty or contains empty data

### `doGov(bytes32 _nonce, uint256 _offset)`
Execute a governance proposal that has failed.

**Parameters:**
- `_nonce` (bytes32): The proposal nonce
- `_offset` (uint256): The offset within the proposal data

**Notes:**
- Reverts if the offset is out of bounds or the proposal hasn't failed

### `getProposalData(bytes32 _nonce, uint256 _offset)`
Get proposal data and failure status.

**Parameters:**
- `_nonce` (bytes32): The proposal nonce
- `_offset` (uint256): The offset within the proposal data

**Returns:**
- `bytes`: The proposal data
- `bool`: The failure status

### `version()`
Get the contract version.

**Returns:**
- `uint256`: The version number

### `proposalLength()`
Get the number of cross-chain invocations in the current proposal.

**Returns:**
- `uint256`: The number of cross-chain invocations

## Internal Functions

### `chainID()`
Get the current chain ID.

**Returns:**
- `uint256`: The current chain ID

### `_c3gov(bytes32 _nonce, uint256 _offset)`
Internal function to execute governance proposals.

**Parameters:**
- `_nonce` (bytes32): The proposal nonce
- `_offset` (uint256): The offset within the proposal data

**Notes:**
- Decodes proposal data into chainId, target, and remoteData
- If chainId matches current chain, executes local call to target address
- If local call fails, marks the proposal as failed
- If chainId doesn't match current chain, marks proposal as failed and emits C3GovernorLog event
- TODO: Add flag to configure whether to use governance or operator for sending

### `_c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)`
Internal function to handle fallback calls.

**Parameters:**
- `_selector` (bytes4): The function selector
- `_data` (bytes): The call data
- `_reason` (bytes): The failure reason

**Returns:**
- `bool`: True if the fallback was handled successfully

**Notes:**
- Overrides the function from C3CallerDApp
- Marks the current proposal as failed by setting hasFailed[_len - 1] = true
- Emits a LogFallback event with selector, data, and reason

## Data Structures

### `Proposal`
Represents a governance proposal.

```solidity
struct Proposal {
    bytes[] data;
    bool[] hasFailed;
}
```

**Fields:**
- `data` (bytes[]): Array of proposal data
- `hasFailed` (bool[]): Array indicating which proposals have failed

## Events

### `NewProposal`
Emitted when a new proposal is created.

```solidity
event NewProposal(bytes32 indexed uuid);
```

### `C3GovernorLog`
Emitted when a cross-chain governance operation is logged.

```solidity
event C3GovernorLog(bytes32 indexed _nonce, uint256 indexed _toChainID, string _to, bytes _toData);
```

### `LogChangeMPC`
Emitted when MPC address is changed.

```solidity
event LogChangeMPC(
    address indexed _oldMPC,
    address indexed _newMPC,
    uint256 indexed _effectiveTime,
    uint256 _chainID
);
```

### `LogFallback`
Emitted when a fallback occurs.

```solidity
event LogFallback(bytes4 _selector, bytes _data, bytes _reason);
```

### `LogChangeGov`
Emitted when governance address is changed.

```solidity
event LogChangeGov(address _gov, address _newGov);
```

### `LogSendParams`
Emitted when parameters are sent.

```solidity
event LogSendParams(address _target, uint256 _chainId, bytes _dataXChain);
```

## Errors

### `C3Governor_InvalidLength`
Thrown when proposal data has invalid length.

```solidity
error C3Governor_InvalidLength(C3ErrorParam);
```

### `C3Governor_OutOfBounds`
Thrown when accessing proposal data out of bounds.

```solidity
error C3Governor_OutOfBounds();
```

### `C3Governor_HasNotFailed`
Thrown when attempting to retry a proposal that hasn't failed.

```solidity
error C3Governor_HasNotFailed();
```

## Usage Examples

### Creating a Single Parameter Proposal
```solidity
// Create a proposal with single parameter
bytes memory proposalData = abi.encode(
    1, // chainId
    "0x1234567890123456789012345678901234567890", // target
    abi.encodeWithSelector(SomeFunction.selector, param1, param2) // remoteData
);

bytes32 nonce = keccak256(abi.encodePacked(block.timestamp, msg.sender));
governor.sendParams(proposalData, nonce);
```

### Creating a Multi-Parameter Proposal
```solidity
// Create a proposal with multiple parameters
bytes[] memory proposalData = new bytes[](2);
proposalData[0] = abi.encode(1, "0x123...", abi.encode(...));
proposalData[1] = abi.encode(137, "0x456...", abi.encode(...));

bytes32 nonce = keccak256(abi.encodePacked(block.timestamp, msg.sender));
governor.sendMultiParams(proposalData, nonce);
```

### Retrying Failed Proposals
```solidity
// Check if a proposal failed
(bytes memory data, bool hasFailed) = governor.getProposalData(nonce, 0);

if (hasFailed) {
    // Retry the failed proposal
    governor.doGov(nonce, 0);
}
```

### Getting Proposal Information
```solidity
// Get current proposal length
uint256 length = governor.proposalLength();

// Get current proposal ID
bytes32 currentProposalId = governor.proposalId();
```

## Security Considerations

1. **Access Control**: Only the governor can create proposals
2. **Proposal Validation**: Validates proposal data before execution
3. **Failure Handling**: Tracks failed proposals for retry mechanisms
4. **Cross-Chain Safety**: Handles cross-chain proposal execution safely
5. **Fallback Mechanism**: Provides fallback handling for failed operations

## Dependencies

- `@openzeppelin/contracts/utils/Strings.sol`
- `C3CallerUtils.sol`
- `C3GovernDApp.sol`
- `IC3Governor.sol`
