# C3UUIDKeeperUpgradeable

Upgradeable contract for managing Universally Unique Identifiers (UUIDs) in the C3 protocol. This contract is responsible for generating, tracking, and validating UUIDs for cross-chain operations to prevent replay attacks and ensure uniqueness.

## Key Features

- UUID generation with nonce-based uniqueness
- UUID completion tracking
- UUID revocation capabilities
- Utilities to calculate UUID before OR after it happens
- Upgradeable functionality via UUPS pattern

## Constructor

```solidity
constructor()
```

Disable initializers.

## State Variables

### completedSwapin
```solidity
mapping(bytes32 => bool) public completedSwapin
```
Mapping of UUID to completion status

### uuid2Nonce
```solidity
mapping(bytes32 => uint256) public uuid2Nonce
```
Mapping of UUID to its associated nonce

### currentNonce
```solidity
uint256 public currentNonce
```
Current nonce for UUID generation

## Modifiers

### autoIncreaseSwapoutNonce
```solidity
modifier autoIncreaseSwapoutNonce()
```
Modifier to automatically increase the swapout nonce.

**Notice:** Increments the current nonce before executing the function

### checkCompletion
```solidity
modifier checkCompletion(bytes32 _uuid)
```
Modifier to check if a UUID has already been completed.

**Parameters:**
- `_uuid`: The UUID to check

**Notice:** Reverts if the UUID has already been completed

## Functions

### initialize
```solidity
function initialize() public initializer
```
Initialize the upgradeable C3UUIDKeeper contract.

**Dev:** This function can only be called once during deployment

### genUUID
```solidity
function genUUID(
    uint256 _dappID,
    string calldata _to,
    string calldata _toChainID,
    bytes calldata _data
) external onlyOperator autoIncreaseSwapoutNonce returns (bytes32 _uuid)
```
Generate a new UUID for cross-chain operations and increment the nonce.

**Parameters:**
- `_dappID`: The DApp identifier
- `_to`: The target address on the destination chain
- `_toChainID`: The destination chain ID
- `_data`: The calldata for the cross-chain operation

**Returns:**
- `bytes32`: The generated UUID

**Dev:** Only operator (C3Caller contract) can call this function

### registerUUID
```solidity
function registerUUID(bytes32 _uuid, uint256 _dappID) external onlyOperator checkCompletion(_uuid)
```
Register a UUID as completed.

**Parameters:**
- `_uuid`: The UUID to register as completed
- `_dappID`: The DApp identifier associated with the UUID

**Dev:** Only operator (C3Caller contract) can call this function

### revokeSwapin
```solidity
function revokeSwapin(bytes32 _uuid, uint256 _dappID) external onlyGov
```
Revoke a completed UUID (governance only).

**Parameters:**
- `_uuid`: The UUID to revoke
- `_dappID`: The DApp identifier associated with the UUID

**Dev:** Only the governance address can call this function

### isCompleted
```solidity
function isCompleted(bytes32 _uuid) external view returns (bool)
```
Check if a UUID has been completed.

**Parameters:**
- `_uuid`: The UUID to check

**Returns:**
- `bool`: True if the UUID has been completed, false otherwise

### doesUUIDExist
```solidity
function doesUUIDExist(bytes32 _uuid) public view returns (bool)
```
Check if a UUID exists in the system.

**Parameters:**
- `_uuid`: The UUID to check

**Returns:**
- `bool`: True if the UUID exists, false otherwise

### calcCallerUUID
```solidity
function calcCallerUUID(
    address _from,
    uint256 _dappID,
    string calldata _to,
    string calldata _toChainID,
    bytes calldata _data
) public view returns (bytes32)
```
Calculate the UUID for a given payload without incrementing the nonce.

**Parameters:**
- `_from`: The address of the caller (this is always the C3Caller contract)
- `_dappID`: The DApp identifier
- `_to`: The target address on the destination chain
- `_toChainID`: The destination chain ID
- `_data`: The calldata for the cross-chain operation

**Returns:**
- `bytes32`: The calculated UUID

### calcCallerUUIDWithNonce
```solidity
function calcCallerUUIDWithNonce(
    address _from,
    uint256 _dappID,
    string calldata _to,
    string calldata _toChainID,
    bytes calldata _data,
    uint256 _nonce
) public view returns (bytes32)
```
Calculate the UUID for a given payload with a specific nonce, without incrementing it.

**Parameters:**
- `_from`: The address of the caller (this is always the C3Caller contract)
- `_dappID`: The DApp identifier
- `_to`: The target address on the destination chain
- `_toChainID`: The destination chain ID
- `_data`: The calldata for the cross-chain operation
- `_nonce`: The specific nonce to use

**Returns:**
- `bytes32`: The calculated UUID

### calcCallerEncode
```solidity
function calcCallerEncode(
    address _from,
    uint256 _dappID,
    string calldata _to,
    string calldata _toChainID,
    bytes calldata _data
) public view returns (bytes memory)
```
Calculate the encoded data for a given payload with a specific nonce, without incrementing it.

**Parameters:**
- `_from`: The address of the caller
- `_dappID`: The DApp identifier
- `_to`: The target address on the destination chain
- `_toChainID`: The destination chain identifier
- `_data`: The calldata for the cross-chain operation

**Returns:**
- `bytes`: The encoded data for the UUID

**Dev:** This function returns the input to keccak256 that would produce the corresponding UUID

### _authorizeUpgrade
```solidity
function _authorizeUpgrade(address newImplementation) internal virtual override onlyGov
```
Internal function to authorize upgrades.

**Parameters:**
- `newImplementation`: The new implementation address

**Dev:** Only governance can authorize upgrades

## Events

### UUIDGenerated
```solidity
event UUIDGenerated(
    bytes32 indexed uuid,
    uint256 indexed dappID,
    address caller,
    string to,
    string toChainID,
    uint256 nonce,
    bytes data
)
```

### UUIDCompleted
```solidity
event UUIDCompleted(bytes32 indexed uuid, uint256 indexed dappID, address caller)
```

### UUIDRevoked
```solidity
event UUIDRevoked(bytes32 indexed uuid, uint256 indexed dappID, address caller)
```

## Errors

### C3UUIDKeeper_UUIDAlreadyCompleted
```solidity
error C3UUIDKeeper_UUIDAlreadyCompleted(bytes32)
```

### C3UUIDKeeper_UUIDAlreadyExists
```solidity
error C3UUIDKeeper_UUIDAlreadyExists(bytes32)
```

## Author

@potti ContinuumDAO

## Dev

This contract is critical for cross-chain security and uniqueness. It is the upgradeable version of the UUID management system