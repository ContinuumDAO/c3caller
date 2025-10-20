# C3CallerUpgradeable

Upgradeable version of the main C3Caller contract for handling cross-chain calls. This contract provides the same functionality as C3Caller but with upgradeable capabilities using the UUPS (Universal Upgradeable Proxy Standard) pattern.

## Key Features

- Cross-chain call initiation (c3call)
- Cross-chain broadcast functionality (c3broadcast)
- Cross-chain message execution (execute)
- Fallback mechanism for failed calls (c3Fallback)
- Pausable functionality for emergency stops
- Governance integration for access control
- Upgradeable functionality via UUPS pattern

## Constructor

```solidity
constructor()
```

Disable initializers.

## State Variables

### context
```solidity
C3Context public context
```
Current execution context for cross-chain operations, set/reset during each execution

### uuidKeeper
```solidity
address public uuidKeeper
```
Address of the UUID keeper contract for managing unique identifiers

## Functions

### initialize
```solidity
function initialize(address _uuidKeeper) public initializer
```
Initializer for the upgradeable C3Caller contract.

**Parameters:**
- `_uuidKeeper`: Address of the UUID keeper contract

**Dev:** This function can only be called once during deployment

### c3call (with extra data)
```solidity
function c3call(
    uint256 _dappID,
    string calldata _to,
    string calldata _toChainID,
    bytes calldata _data,
    bytes memory _extra
) external whenNotPaused
```
Initiate a cross-chain call with extra custom data.

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_to`: The target address on the destination network (C3CallerDApp implementation)
- `_toChainID`: The destination chain ID
- `_data`: The calldata to execute on the destination network (ABI encoded)
- `_extra`: Additional custom data for the cross-chain call

**Dev:** Calls `_c3call` with msg.sender as the caller

### c3call (without extra data)
```solidity
function c3call(
    uint256 _dappID,
    string calldata _to,
    string calldata _toChainID,
    bytes calldata _data
) external whenNotPaused
```
Initiate a cross-chain call without extra custom data.

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_to`: The target address on the destination network (C3CallerDApp implementation)
- `_toChainID`: The destination network' chain ID
- `_data`: The calldata to execute on the destination network (ABI encoded)

**Dev:** Called within registered DApps to initiate cross-chain transactions. Calls `_c3call` with msg.sender as the caller

### c3broadcast
```solidity
function c3broadcast(
    uint256 _dappID,
    string[] calldata _to,
    string[] calldata _toChainIDs,
    bytes calldata _data
) external whenNotPaused
```
Initiate cross-chain broadcasts to multiple chains.

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_to`: Array of target addresses on destination networks (C3CallerDApp destination implementations)
- `_toChainIDs`: Array of destination chain IDs
- `_data`: The calldata to execute on each destination network (ABI encoded)

**Dev:** Called within registered DApps to broadcast transactions to multiple other chains. Calls `_c3broadcast` with msg.sender as the caller

### execute
```solidity
function execute(uint256 _dappID, C3EvmMessage calldata _message) external onlyOperator whenNotPaused
```
Execute a cross-chain message (this is called on the destination chain).

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_message`: The cross-chain message to execute

**Dev:** Called by MPC network to execute cross-chain messages

### c3Fallback
```solidity
function c3Fallback(uint256 _dappID, C3EvmMessage calldata _message) external onlyOperator whenNotPaused
```
Execute a fallback call for reverted cross-chain operations.

**Parameters:**
- `_dappID`: The ID of the C3CallerDApp implementation
- `_message`: The cross-chain calldata that failed to execute

**Dev:** Called by the MPC network on the source network

## Internal Functions

### _c3call
```solidity
function _c3call(
    uint256 _dappID,
    address _caller,
    string calldata _to,
    string calldata _toChainID,
    bytes calldata _data,
    bytes memory _extra
) internal
```
Internal function to initiate a cross-chain call.

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_caller`: The address initiating the call (C3CallerDApp implementation)
- `_to`: The target address on the destination network (C3CallerDApp implementation)
- `_toChainID`: The destination chain ID
- `_data`: The calldata to execute on the destination network (ABI encoded)
- `_extra`: Additional custom data for the cross-chain call

### _c3broadcast
```solidity
function _c3broadcast(
    uint256 _dappID,
    address _caller,
    string[] calldata _to,
    string[] calldata _toChainIDs,
    bytes calldata _data
) internal
```
Internal function to initiate multiple cross-chain calls.

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_caller`: The address initiating the broadcast (C3CallerDApp source implementation)
- `_to`: Array of target addresses on destination networks (C3CallerDApp destination implementations)
- `_toChainIDs`: Array of destination chain IDs
- `_data`: The calldata to execute on each destination network (ABI encoded)

### _execute
```solidity
function _execute(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal
```
Internal function to execute cross-chain messages on the destination network.

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_txSender`: The transaction sender address (should be the MPC network)
- `_message`: The cross-chain message to execute

**Dev:** If the call fails, emits a `LogFallbackCall` event which routes to _c3Fallback

### _c3Fallback
```solidity
function _c3Fallback(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal
```
Internal function to handle fallback calls.

**Parameters:**
- `_dappID`: The DApp identifier of the C3CallerDApp implementation
- `_txSender`: The transaction sender address
- `_message`: The cross-chain calldata that reverted during `execute`

### _authorizeUpgrade
```solidity
function _authorizeUpgrade(address newImplementation) internal virtual override onlyOperator
```
Internal function to authorize upgrades.

**Parameters:**
- `newImplementation`: The new implementation address

**Dev:** Only operators can authorize upgrades

## Events

### LogC3Call
```solidity
event LogC3Call(
    uint256 indexed dappID,
    bytes32 indexed uuid,
    address caller,
    string toChainID,
    string to,
    bytes data,
    bytes extra
)
```

### LogFallbackCall
```solidity
event LogFallbackCall(uint256 indexed dappID, bytes32 indexed uuid, string to, bytes data, bytes reasons)
```

### LogExecCall
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
)
```

### LogExecFallback
```solidity
event LogExecFallback(
    uint256 indexed dappID,
    address indexed to,
    bytes32 indexed uuid,
    string fromChainID,
    string sourceTx,
    bytes data,
    bytes reason
)
```

## Errors

### C3Caller_OnlyAuthorized
```solidity
error C3Caller_OnlyAuthorized(C3ErrorParam, C3ErrorParam)
```

### C3Caller_InvalidLength
```solidity
error C3Caller_InvalidLength(C3ErrorParam)
```

### C3Caller_InvalidAccountLength
```solidity
error C3Caller_InvalidAccountLength(C3ErrorParam)
```

### C3Caller_LengthMismatch
```solidity
error C3Caller_LengthMismatch(C3ErrorParam, C3ErrorParam)
```

### C3Caller_InvalidDAppID
```solidity
error C3Caller_InvalidDAppID(uint256, uint256)
```

### C3Caller_UUIDAlreadyCompleted
```solidity
error C3Caller_UUIDAlreadyCompleted(bytes32)
```

### C3Caller_IsZero
```solidity
error C3Caller_IsZero(C3ErrorParam)
```

## Structs

### C3Context
```solidity
struct C3Context {
    bytes32 swapID;
    string fromChainID;
    string sourceTx;
}
```

### C3EvmMessage
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

## Author

@potti ContinuumDAO

## Dev

This contract is the upgradeable version of the primary entry point for cross-chain operations