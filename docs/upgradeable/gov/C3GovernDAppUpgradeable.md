# C3GovernDAppUpgradeable

Upgradeable base contract that extends C3CallerDApp for governance functionality in the C3 protocol. This contract provides governance-specific features including delayed governance changes and MPC address validation. It features upgradeable storage using the ERC-7201 storage pattern.

The key difference with C3GovClient is that this contract registers a DApp ID. DApp developers can implement it in their C3DApp to allow governance functionality.

## Key Features

- Delayed governance address changes
- MPC address validation
- Governance-driven cross-chain operations
- Fallback mechanism for failed operations
- Upgradeable storage using ERC-7201 pattern

## Storage Structure

### C3GovernDAppStorage
```solidity
struct C3GovernDAppStorage {
    /// @notice Delay period for governance changes (default: 2 days)
    uint256 delay;
    /// @notice The old governance address
    address _oldGov;
    /// @notice The new governance address
    address _newGov;
    /// @notice The delay between declaring a new governance address and it being confirmed
    uint256 _newGovEffectiveTime;
    /// @notice Mapping of MPC addresses to their validity
    mapping(address => bool) txSenders;
    /// @notice Array of all txSender addresses
    address[] senders;
}
```

Storage struct for C3GovernDApp using ERC-7201 storage pattern.

## Functions

### delay
```solidity
function delay() public view virtual returns (uint256)
```
Get the delay between declaring a new governance address and it being confirmed.

**Returns:**
- `uint256`: The delay in seconds

### _oldGov
```solidity
function _oldGov() internal view virtual returns (address)
```
Get the old governance address (valid until _newGovEffectiveTime).

**Returns:**
- `address`: The old governance address

### _newGov
```solidity
function _newGov() internal view virtual returns (address)
```
Get the new governance address (valid after _newGovEffectiveTime).

**Returns:**
- `address`: The new governance address

### _newGovEffectiveTime
```solidity
function _newGovEffectiveTime() internal view virtual returns (uint256)
```
Get the time after which the new governance address is valid.

**Returns:**
- `uint256`: The new governance address' effective time in seconds

### txSenders
```solidity
function txSenders(address sender) public view virtual returns (bool)
```
Get the validity of `sender`.

**Parameters:**
- `sender`: The address to check

**Returns:**
- `bool`: True if `sender` is a txSender (MPC address), false otherwise

### senders
```solidity
function senders(uint256 _index) public view returns (address)
```
Get txSender address by index.

**Parameters:**
- `_index`: The index of the txSender

**Returns:**
- `address`: The txSender address at the specified index

### gov
```solidity
function gov() public view virtual returns (address)
```
Get the current governance address.

**Returns:**
- `address`: The current governance address (new or old based on effective time)

### changeGov
```solidity
function changeGov(address newGov_) external virtual onlyGov
```
Change the governance address. The new governance address will be valid after delay.

**Parameters:**
- `newGov_`: The new governance address

**Dev:** Reverts if the new governance address is zero. Only governance or C3Caller can call this function

### setDelay
```solidity
function setDelay(uint256 _delay) external virtual onlyGov
```
Set the delay period for governance changes.

**Parameters:**
- `_delay`: The new delay period in seconds

**Dev:** Only governance or C3Caller can call this function

### addTxSender
```solidity
function addTxSender(address _txSender) external virtual onlyGov
```
Add an MPC address that can call functions that should be targeted by C3Caller execute.

**Parameters:**
- `_txSender`: The MPC address to add

**Dev:** Only governance or C3Caller can call this function

### disableTxSender
```solidity
function disableTxSender(address _txSender) external virtual onlyGov
```
Disable an MPC address, which will no longer be able to call functions targeted by C3Caller execute.

**Parameters:**
- `_txSender`: The MPC address to disable

**Dev:** Only governance or C3Caller can call this function

### doGov
```solidity
function doGov(string memory _to, string memory _toChainID, bytes memory _data) external virtual onlyGov
```
Execute an arbitrary cross-chain operation on a single target.

**Parameters:**
- `_to`: The target address on the destination network
- `_toChainID`: The destination chain ID
- `_data`: The calldata to execute

**Dev:** Only governance or C3Caller can call this function

### doGovBroadcast
```solidity
function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data) external virtual onlyGov
```
Execute an arbitrary cross-chain operation on multiple targets and multiple networks.

**Parameters:**
- `_targets`: Array of target addresses on destination networks
- `_toChainIDs`: Array of destination chain IDs
- `_data`: The calldata to execute

**Dev:** Only governance or C3Caller can call this function

### getAllTxSenders
```solidity
function getAllTxSenders() external view returns (address[] memory)
```
Get all txSender addresses.

**Returns:**
- `address[]`: Array of all txSender addresses

### isValidSender
```solidity
function isValidSender(address _txSender) external view virtual override(IC3CallerDApp, C3CallerDAppUpgradeable) returns (bool)
```
Check if an address is a valid MPC address executor for this DApp.

**Parameters:**
- `_txSender`: The address to check

**Returns:**
- `bool`: True if the address is a valid sender, false otherwise

## Internal Functions

### _getC3GovernDAppStorage
```solidity
function _getC3GovernDAppStorage() private pure returns (C3GovernDAppStorage storage $)
```
Get the storage struct for C3GovernDApp.

**Returns:**
- `C3GovernDAppStorage`: The storage struct

### __C3GovernDApp_init
```solidity
function __C3GovernDApp_init(address _gov, address _c3caller, address _txSender, uint256 _dappID) internal onlyInitializing
```
Internal initializer for the upgradeable C3GovernDApp contract.

**Parameters:**
- `_gov`: The initial governance address
- `_c3caller`: The C3Caller address
- `_txSender`: The initial valid MPC address
- `_dappID`: The DApp ID (obtained from registering with C3DAppManager)

## Modifiers

### onlyGov
```solidity
modifier onlyGov()
```
Modifier to restrict access to governance or C3Caller.

**Dev:** Reverts if the caller is neither governance address nor C3Caller

## Events

### LogChangeGov
```solidity
event LogChangeGov(address oldGov, address newGov, uint256 effectiveTime, uint256 chainId)
```

### LogTxSender
```solidity
event LogTxSender(address txSender, bool enabled)
```

## Errors

### C3GovernDApp_OnlyAuthorized
```solidity
error C3GovernDApp_OnlyAuthorized(C3ErrorParam, C3ErrorParam)
```

### C3GovernDApp_IsZeroAddress
```solidity
error C3GovernDApp_IsZeroAddress(C3ErrorParam)
```

## Author

@potti ContinuumDAO

## Dev

This contract provides upgradeable governance functionality for DApps