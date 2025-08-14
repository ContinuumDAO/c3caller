# C3Caller

## Overview

C3Caller is the main contract for handling cross-chain calls in the Continuum
Cross-Chain protocol. This contract serves as the central hub for initiating and
executing cross-chain transactions, integrating with governance, UUID
management, and DApp functionality.

### Key Features

**Source Network Operations:**
- Cross-chain call initiation (`c3call`)
- Cross-chain multiple calls functionality (`c3broadcast`)
- Fallback mechanism for failed calls (`c3Fallback`)

**Destination Network Operations:**
- Cross-chain message execution (`execute`)

**Additional Features:**
- Pausable functionality for early-stage security
- Governance integration for access control (adding/removing valid MPC addresses)
- UUID management for transaction tracking

## Contract Details

- **Contract Name:** `C3Caller`
- **Inherits:** `IC3Caller`, `C3GovClient`, `Ownable`, `Pausable`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## State Variables

### `context`
```solidity
C3Context public context
```
Current execution context for cross-chain operations, set/reset during each
execution.

### `uuidKeeper`
```solidity
address public uuidKeeper
```
Address of the UUID keeper contract for managing unique identifiers.

## Constructor

### `constructor(address _uuidKeeper)`
Initializes the C3Caller contract.

**Parameters:**
- `_uuidKeeper` (address): Address of the UUID keeper contract

**Notes:**
- Initializes the Owner of the contract to the `msg.sender`
- Inherits from `C3GovClient`, `Ownable`, and `Pausable`

## Public Functions

### `isExecutor(address _sender)`
Check if an address is an authorized executor (aka operator).
Functions with this modifier should only be called by the MPC address.

**Parameters:**
- `_sender` (address): Address to check

**Returns:**
- `bool`: True if the address is an operator, false otherwise

### `c3caller()`
Get the address of this C3Caller contract, for backwards compatibility.

**Returns:**
- `address`: The address of this contract

### `isCaller(address _sender)`
Check if an address is the C3Caller contract itself, for backwards compatibility.

**Parameters:**
- `_sender` (address): Address to check

**Returns:**
- `bool`: True if the address is this contract, false otherwise

## External Functions

### `c3call(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)`
Initiate a cross-chain call without extra custom data.

**Parameters:**
- `_dappID` (uint256): The ID of the C3CallerDApp implementation
- `_to` (string): The target address on the destination chain (C3CallerDApp implementation)
- `_toChainID` (string): The destination chain ID
- `_data` (bytes): The calldata to execute on the destination chain (ABI encoded)

**Modifiers:**
- `whenNotPaused`

**Notes:**
- Called within registered DApps to initiate cross-chain transactions
- Calls `_c3call` with `msg.sender` as the caller

### `c3call(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data, bytes memory _extra)`
Initiate a cross-chain call with extra custom data.

**Parameters:**
- `_dappID` (uint256): The DApp identifier of the C3CallerDApp implementation
- `_to` (string): The target address on the destination chain (C3CallerDApp implementation)
- `_toChainID` (string): The destination chain ID
- `_data` (bytes): The calldata to execute on the destination chain (ABI encoded)
- `_extra` (bytes): Additional custom data for the cross-chain call

**Modifiers:**
- `whenNotPaused`

**Notes:**
- Calls `_c3call` with `msg.sender` as the caller

### `c3broadcast(uint256 _dappID, string[] calldata _to, string[] calldata _toChainIDs, bytes calldata _data)`
Initiate cross-chain broadcasts to multiple chains.

**Parameters:**
- `_dappID` (uint256): The ID of the C3CallerDApp implementation
- `_to` (string[]): Array of target addresses on destination chains (C3CallerDApp implementation)
- `_toChainIDs` (string[]): Array of destination chain IDs
- `_data` (bytes): The calldata to execute on each destination chain (ABI encoded)

**Modifiers:**
- `whenNotPaused`

**Notes:**
- Called within registered DApps to broadcast transactions to multiple other chains
- Calls `_c3broadcast` with `msg.sender` as the caller

### `execute(uint256 _dappID, C3EvmMessage calldata _message)`
Execute a cross-chain message (this is called on the target chain).

**Parameters:**
- `_dappID` (uint256): The ID of the C3CallerDApp implementation
- `_message` (C3EvmMessage): The cross-chain message to execute

**Modifiers:**
- `onlyOperator`
- `whenNotPaused`

**Notes:**
- Called by MPC network to execute cross-chain messages

### `c3Fallback(uint256 _dappID, C3EvmMessage calldata _message)`
Execute a fallback call for failed cross-chain operations (this is called on the origin chain).

**Parameters:**
- `_dappID` (uint256): The ID of the C3CallerDApp implementation
- `_message` (C3EvmMessage): The cross-chain calldata that failed to execute

**Modifiers:**
- `onlyOperator`
- `whenNotPaused`

**Notes:**
- Called by MPC network to handle failed cross-chain calls

## Internal Functions

### `_c3call(uint256 _dappID, address _caller, string calldata _to, string calldata _toChainID, bytes calldata _data, bytes memory _extra)`
Internal function to initiate a cross-chain call.

**Parameters:**
- `_dappID` (uint256): The DApp identifier of the C3CallerDApp implementation
- `_caller` (address): The address initiating the call
- `_to` (string): The target address on the destination chain (C3CallerDApp implementation)
- `_toChainID` (string): The destination chain ID
- `_data` (bytes): The calldata to execute on the destination chain (ABI encoded)
- `_extra` (bytes): Additional custom data for the cross-chain call

### `_c3broadcast(uint256 _dappID, address _caller, string[] calldata _to, string[] calldata _toChainIDs, bytes calldata _data)`
Internal function to initiate multiple cross-chain calls.

**Parameters:**
- `_dappID` (uint256): The ID of the C3CallerDApp implementation
- `_caller` (address): The address initiating the broadcast
- `_to` (string[]): Array of target addresses on destination chains (C3CallerDApp implementation)
- `_toChainIDs` (string[]): Array of destination chain IDs
- `_data` (bytes): The calldata to execute on each destination chain (ABI encoded)

### `_execute(uint256 _dappID, address _txSender, C3EvmMessage calldata _message)`
Internal function to execute cross-chain messages.

**Parameters:**
- `_dappID` (uint256): The ID of the C3CallerDApp implementation
- `_txSender` (address): The transaction sender address (should be the MPC network)
- `_message` (C3EvmMessage): The cross-chain message to execute

**Notes:**
- Calls `_c3Fallback` if the call fails

### `_c3Fallback(uint256 _dappID, address _txSender, C3EvmMessage calldata _message)`
Internal function to handle fallback calls.

**Parameters:**
- `_dappID` (uint256): The ID of the C3CallerDApp implementation
- `_txSender` (address): The transaction sender address
- `_message` (C3EvmMessage): The cross-chain calldata that failed to execute

## Events

### `LogC3Call`
Emitted when a cross-chain call is initiated.

```solidity
event LogC3Call(
    uint256 indexed dappID,
    bytes32 indexed uuid,
    address caller,
    string toChainID,
    string to,
    bytes data,
    bytes extra
);
```

### `LogFallbackCall`
Emitted when a fallback call is initiated.

```solidity
event LogFallbackCall(
    uint256 indexed dappID,
    bytes32 indexed uuid,
    string to,
    bytes data,
    bytes reasons
);
```

### `LogExecCall`
Emitted when a cross-chain message is executed.

```solidity
event LogExecCall(
    uint256 indexed dappID,
    address indexed to,
    bytes32 indexed uuid,
    string fromChainID,
    string sourceTx,
    bytes data,
    bool success,
    bytes reason
);
```

### `LogExecFallback`
Emitted when a fallback call is executed.

```solidity
event LogExecFallback(
    uint256 indexed dappID,
    address indexed to,
    bytes32 indexed uuid,
    string fromChainID,
    string sourceTx,
    bytes data,
    bytes reason
);
```

## Errors

### `C3Caller_OnlyAuthorized`
Thrown when an unauthorized address attempts to perform an operation.

```solidity
error C3Caller_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
```

### `C3Caller_InvalidLength`
Thrown when a parameter has an invalid length.

```solidity
error C3Caller_InvalidLength(C3ErrorParam);
```

### `C3Caller_InvalidAccountLength`
Thrown when an account parameter has an invalid length.

```solidity
error C3Caller_InvalidAccountLength(C3ErrorParam);
```

### `C3Caller_LengthMismatch`
Thrown when two arrays have mismatched lengths.

```solidity
error C3Caller_LengthMismatch(C3ErrorParam, C3ErrorParam);
```

### `C3Caller_InvalidDAppID`
Thrown when the DApp ID doesn't match the expected value.

```solidity
error C3Caller_InvalidDAppID(uint256, uint256);
```

### `C3Caller_UUIDAlreadyCompleted`
Thrown when attempting to execute a UUID that has already been completed.

```solidity
error C3Caller_UUIDAlreadyCompleted(bytes32);
```

### `C3Caller_IsZero`
Thrown when a required parameter is zero.

```solidity
error C3Caller_IsZero(C3ErrorParam);
```

## Data Structures

### `C3Context`
Represents the current execution context for cross-chain operations.

```solidity
struct C3Context {
    bytes32 swapID;
    string fromChainID;
    string sourceTx;
}
```

**Fields:**
- `swapID` (bytes32): The UUID of the current cross-chain operation
- `fromChainID` (string): The source chain ID
- `sourceTx` (string): The source transaction hash

### `C3EvmMessage`
Represents a cross-chain message to be executed.

```solidity
struct C3EvmMessage {
    bytes32 uuid;
    address to;
    string fromChainID;
    string sourceTx;
    string fallbackTo;
    bytes data;
}
```

**Fields:**
- `uuid` (bytes32): Unique identifier for the cross-chain operation
- `to` (address): Target contract address on the destination chain
- `fromChainID` (string): Source chain ID
- `sourceTx` (string): Source transaction hash
- `fallbackTo` (string): Fallback address for failed operations
- `data` (bytes): Calldata to execute on the destination chain

## Usage Examples

### Initiating a Cross-Chain Call
```solidity
// Basic cross-chain call
c3call(
    dappID,
    "0x1234567890123456789012345678901234567890",
    "1", // Ethereum mainnet
    abi.encodeWithSelector(SomeFunction.selector, param1, param2)
);

// Cross-chain call with extra data
c3call(
    dappID,
    "0x1234567890123456789012345678901234567890",
    "137", // Polygon
    abi.encodeWithSelector(SomeFunction.selector, param1, param2),
    abi.encode(extraParam1, extraParam2)
);
```

### Broadcasting to Multiple Chains
```solidity
string[] memory targets = new string[](2);
targets[0] = "0x1234567890123456789012345678901234567890";
targets[1] = "0x0987654321098765432109876543210987654321";

string[] memory chainIDs = new string[](2);
chainIDs[0] = "1";   // Ethereum mainnet
chainIDs[1] = "137"; // Polygon

c3broadcast(
    dappID,
    targets,
    chainIDs,
    abi.encodeWithSelector(SomeFunction.selector, param1, param2)
);
```

## Security Considerations

1. **Access Control**: Only authorized operators can execute cross-chain messages and fallback calls
2. **Pausability**: The contract can be paused in emergency situations
3. **UUID Management**: Prevents replay attacks by tracking completed operations
4. **Sender Validation**: Validates that cross-chain messages come from authorized sources
5. **DApp ID Validation**: Ensures messages are executed on the correct DApp implementation

## Dependencies

- `@openzeppelin/contracts/access/Ownable.sol`
- `@openzeppelin/contracts/utils/Pausable.sol`
- `@openzeppelin/contracts/utils/Address.sol`
- `IC3Caller.sol`
- `IC3CallerDApp.sol`
- `C3GovClient.sol`
- `IC3UUIDKeeper.sol`
- `C3CallerUtils.sol`