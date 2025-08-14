# C3UUIDKeeper

## Overview

C3UUIDKeeper is a contract for managing unique identifiers (UUIDs) in the C3 protocol. This contract is responsible for generating, tracking, and validating UUIDs for cross-chain operations to prevent replay attacks and ensure uniqueness.

### Key Features

- UUID generation with nonce-based uniqueness
- UUID completion tracking
- UUID revocation capabilities
- Cross-chain UUID calculation utilities

**Note:** This contract is critical for cross-chain security and uniqueness

## Contract Details

- **Contract Name:** `C3UUIDKeeper`
- **Implements:** `IC3UUIDKeeper`
- **Inherits:** `C3GovClient`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## State Variables

### `completedSwapin`
```solidity
mapping(bytes32 => bool) public completedSwapin
```
Mapping of UUID to completion status.

### `uuid2Nonce`
```solidity
mapping(bytes32 => uint256) public uuid2Nonce
```
Mapping of UUID to its associated nonce.

### `currentNonce`
```solidity
uint256 public currentNonce
```
Current nonce for UUID generation.

## Constructor

### `constructor()`
Initializes the C3UUIDKeeper contract.

**Notes:**
- Initializes the contract with the deployer as governor

## Modifiers

### `autoIncreaseSwapoutNonce`
Automatically increase the swapout nonce.

**Notes:**
- Increments the current nonce before executing the function

### `checkCompletion(bytes32 _uuid)`
Check if a UUID has already been completed.

**Parameters:**
- `_uuid` (bytes32): The UUID to check

**Notes:**
- Reverts if the UUID has already been completed

## External Functions

### `isUUIDExist(bytes32 _uuid)`
Check if a UUID exists in the system.

**Parameters:**
- `_uuid` (bytes32): The UUID to check

**Returns:**
- `bool`: True if the UUID exists, false otherwise

### `isCompleted(bytes32 _uuid)`
Check if a UUID has been completed.

**Parameters:**
- `_uuid` (bytes32): The UUID to check

**Returns:**
- `bool`: True if the UUID has been completed, false otherwise

### `revokeSwapin(bytes32 _uuid)`
Revoke a completed UUID (governance only).

**Parameters:**
- `_uuid` (bytes32): The UUID to revoke

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function

### `registerUUID(bytes32 _uuid)`
Register a UUID as completed (operator only).

**Parameters:**
- `_uuid` (bytes32): The UUID to register as completed

**Modifiers:**
- `onlyOperator`
- `checkCompletion`

**Notes:**
- Only operators can call this function

### `genUUID(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)`
Generate a new UUID for cross-chain operations.

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_to` (string): The target address on the destination chain
- `_toChainID` (string): The destination chain identifier
- `_data` (bytes): The calldata for the cross-chain operation

**Returns:**
- `bytes32`: The generated UUID

**Modifiers:**
- `onlyOperator`
- `autoIncreaseSwapoutNonce`

**Notes:**
- Only operators can call this function
- Automatically increments the nonce before execution
- Generates UUID using keccak256 hash of: (contract address, msg.sender, block.chainid, dappID, to, toChainID, currentNonce, data)
- Checks if UUID already exists and reverts if it does
- Stores the nonce associated with the generated UUID

## Public Functions

### `calcCallerUUID(address _from, uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)`
Calculate a UUID for a caller without generating it.

**Parameters:**
- `_from` (address): The address of the caller
- `_dappID` (uint256): The DApp identifier
- `_to` (string): The target address on the destination chain
- `_toChainID` (string): The destination chain identifier
- `_data` (bytes): The calldata for the cross-chain operation

**Returns:**
- `bytes32`: The calculated UUID

### `calcCallerUUIDWithNonce(address _from, uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data, uint256 _nonce)`
Calculate a UUID with a specific nonce.

**Parameters:**
- `_from` (address): The address of the caller
- `_dappID` (uint256): The DApp identifier
- `_to` (string): The target address on the destination chain
- `_toChainID` (string): The destination chain identifier
- `_data` (bytes): The calldata for the cross-chain operation
- `_nonce` (uint256): The specific nonce to use

**Returns:**
- `bytes32`: The calculated UUID

### `calcCallerEncode(address _from, uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)`
Calculate the encoded data for a UUID without generating it.

**Parameters:**
- `_from` (address): The address of the caller
- `_dappID` (uint256): The DApp identifier
- `_to` (string): The target address on the destination chain
- `_toChainID` (string): The destination chain identifier
- `_data` (bytes): The calldata for the cross-chain operation

**Returns:**
- `bytes`: The encoded data for the UUID

## Errors

### `C3UUIDKeeper_UUIDAlreadyExists`
Thrown when attempting to register a UUID that already exists.

```solidity
error C3UUIDKeeper_UUIDAlreadyExists(bytes32);
```

### `C3UUIDKeeper_UUIDAlreadyCompleted`
Thrown when attempting to register a UUID that has already been completed.

```solidity
error C3UUIDKeeper_UUIDAlreadyCompleted(bytes32);
```

## Usage Examples

### UUID Generation and Registration
```solidity
// Generate a new UUID for cross-chain operation
bytes32 uuid = uuidKeeper.genUUID(
    1, // dappID
    "0x1234567890123456789012345678901234567890", // to
    "1", // toChainID
    abi.encodeWithSelector(SomeFunction.selector, param1, param2) // data
);

// Check if UUID exists
bool exists = uuidKeeper.isUUIDExist(uuid);

// Register UUID as completed
uuidKeeper.registerUUID(uuid);

// Check if UUID is completed
bool completed = uuidKeeper.isCompleted(uuid);
```

### UUID Calculation
```solidity
// Calculate UUID without generating it
bytes32 calculatedUUID = uuidKeeper.calcCallerUUID(
    callerAddress,
    1, // dappID
    "0x1234567890123456789012345678901234567890", // to
    "1", // toChainID
    abi.encodeWithSelector(SomeFunction.selector, param1, param2) // data
);

// Calculate UUID with specific nonce
bytes32 uuidWithNonce = uuidKeeper.calcCallerUUIDWithNonce(
    callerAddress,
    1, // dappID
    "0x1234567890123456789012345678901234567890", // to
    "1", // toChainID
    abi.encodeWithSelector(SomeFunction.selector, param1, param2), // data
    123 // nonce
);

// Calculate encoded data
bytes memory encodedData = uuidKeeper.calcCallerEncode(
    callerAddress,
    1, // dappID
    "0x1234567890123456789012345678901234567890", // to
    "1", // toChainID
    abi.encodeWithSelector(SomeFunction.selector, param1, param2) // data
);
```

### UUID Management
```solidity
// Get current nonce
uint256 nonce = uuidKeeper.currentNonce();

// Get nonce for specific UUID
uint256 uuidNonce = uuidKeeper.uuid2Nonce(someUUID);

// Revoke a completed UUID (governance only)
uuidKeeper.revokeSwapin(completedUUID);
```

## Security Considerations

1. **Nonce-Based Uniqueness**: UUIDs are generated using nonces to ensure uniqueness
2. **Completion Tracking**: Prevents replay attacks by tracking completed UUIDs
3. **Access Control**: Only operators can generate and register UUIDs
4. **Revocation Capability**: Governance can revoke completed UUIDs if needed
5. **Cross-Chain Safety**: UUIDs include chain ID to prevent cross-chain replay attacks

## Dependencies

- `C3GovClient.sol`
- `IC3UUIDKeeper.sol`
