# C3CallerDAppUpgradeable

Abstract base contract for upgradeable DApps using the C3 protocol. This contract provides the foundation for DApps to interact with the C3Caller system and handle cross-chain operations in an upgradeable context.

## Key Features

- C3Caller integration
- Contains a DApp ID
- Enables initiation of cross-chain calls
- Fallback mechanism for failed operations
- Upgradeable storage using ERC-7201 pattern

## Storage Structure

### C3CallerDAppStorage
```solidity
struct C3CallerDAppStorage {
    /// @notice The C3Caller address
    address c3caller;
    /// @notice The DApp identifier
    uint256 dappID;
}
```

Storage struct for C3CallerDApp using ERC-7201 storage pattern.

## Functions

### c3caller
```solidity
function c3caller() public view virtual returns (address)
```
Get the C3Caller proxy address.

**Returns:**
- `address`: The C3Caller proxy address

### dappID
```solidity
function dappID() public view virtual returns (uint256)
```
Get the DApp identifier.

**Returns:**
- `uint256`: The DApp identifier

## Modifiers

### onlyCaller
```solidity
modifier onlyCaller()
```
Modifier to restrict access to C3Caller only.

**Dev:** Reverts if the msg.sender is not the C3Caller

## Internal Functions

### _getC3CallerDAppStorage
```solidity
function _getC3CallerDAppStorage() private pure returns (C3CallerDAppStorage storage $)
```
Get the storage struct for C3CallerDApp.

**Returns:**
- `C3CallerDAppStorage`: The storage struct

### __C3CallerDApp_init
```solidity
function __C3CallerDApp_init(address _c3caller, uint256 _dappID) internal onlyInitializing
```
Internal initializer for the upgradeable C3CallerDApp contract.

**Parameters:**
- `_c3caller`: The C3Caller proxy address
- `_dappID`: The DApp identifier

### c3Fallback
```solidity
function c3Fallback(
    uint256 _dappID,
    bytes calldata _data,
    bytes calldata _reason
) external virtual override onlyCaller returns (bool)
```
Handle fallbacks from C3Caller (calls that reverted on a destination network).

**Parameters:**
- `_dappID`: The DApp identifier
- `_data`: The call data
- `_reason`: The failure reason

**Returns:**
- `bool`: True if the fallback was handled successfully

**Dev:** Only C3Caller can call this function

### _c3call (without extra data)
```solidity
function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal virtual
```
Internal function to initiate a cross-chain call.

**Parameters:**
- `_to`: The target address on the destination chain (must be same DApp ID)
- `_toChainID`: The destination chain ID
- `_data`: The calldata to execute on target contract

### _c3call (with extra data)
```solidity
function _c3call(
    string memory _to,
    string memory _toChainID,
    bytes memory _data,
    bytes memory _extra
) internal virtual
```
Internal function to initiate a cross-chain call with arbitrary extra data.

**Parameters:**
- `_to`: The target address on the destination chain
- `_toChainID`: The destination chain ID
- `_data`: The calldata to execute on the target contract
- `_extra`: Additional arbitrary data for the cross-chain call

### _c3broadcast
```solidity
function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal virtual
```
Internal function to initiate cross-chain broadcasts.

**Parameters:**
- `_to`: Array of target addresses on destination chains
- `_toChainIDs`: Array of destination chain IDs
- `_data`: The calldata to execute on the target contracts

### _c3Fallback
```solidity
function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason) internal virtual returns (bool)
```
Internal function to handle fallback calls.

**Parameters:**
- `_selector`: The function selector of the call that reverted
- `_data`: The calldata of the call that reverted
- `_reason`: The revert reason (argument of require statement OR ABI encoded custom error with its arguments)

**Returns:**
- `bool`: True if the fallback was handled successfully (user-implemented)

**Dev:** This function must be implemented by derived contracts to handle failed cross-chain executions

### isValidSender
```solidity
function isValidSender(address _txSender) external view virtual returns (bool)
```
Validates if an address that called C3Caller execute and subsequently a function on this DApp.

**Parameters:**
- `_txSender`: The address to check

**Returns:**
- `bool`: True if the address has been previously validated

**Dev:** This function must be implemented by derived contracts

### _context
```solidity
function _context() internal view virtual returns (bytes32 uuid, string memory fromChainID, string memory sourceTx)
```
Internal function to get some useful information related to the transaction on the source network.

**Returns:**
- `uuid`: The UUID of the current cross-chain operation
- `fromChainID`: The source chain identifier
- `sourceTx`: The source transaction hash

**Dev:** Accessible in functions that implement `onlyCaller` modifier

## Events

### C3CallerDApp_OnlyAuthorized
```solidity
event C3CallerDApp_OnlyAuthorized(C3ErrorParam, C3ErrorParam)
```

### C3CallerDApp_InvalidDAppID
```solidity
event C3CallerDApp_InvalidDAppID(uint256, uint256)
```

## Errors

### C3CallerDApp_OnlyAuthorized
```solidity
error C3CallerDApp_OnlyAuthorized(C3ErrorParam, C3ErrorParam)
```

### C3CallerDApp_InvalidDAppID
```solidity
error C3CallerDApp_InvalidDAppID(uint256, uint256)
```

## Author

@potti ContinuumDAO

## Dev

This contract serves as the base for all upgradeable C3Caller DApps