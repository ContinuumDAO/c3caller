# C3GovernDApp

Base contract that extends C3CallerDApp for governance functionality in the C3 protocol. This contract provides governance-specific features including delayed governance changes and MPC address validation.

The key difference with C3GovClient is that this contract registers a DApp ID. DApp developers can implement it in their C3DApp to allow governance functionality.

## Key Features

- Delayed governance address changes
- MPC address validation
- Governance-driven cross-chain operations
- Fallback mechanism for failed operations

## Constructor

```solidity
constructor(address _gov, address _c3caller, address _txSender, uint256 _dappID)
```

**Parameters:**
- `_gov`: The initial governance address
- `_c3caller`: The C3Caller address
- `_txSender`: The initial valid MPC address
- `_dappID`: The DApp ID (obtained from registering with C3DAppManager)

## State Variables

### delay
```solidity
uint256 public delay
```
Delay period for governance changes (default: 2 days)

### _oldGov
```solidity
address internal _oldGov
```
The old governance address

### _newGov
```solidity
address internal _newGov
```
The new governance address

### _newGovEffectiveTime
```solidity
uint256 internal _newGovEffectiveTime
```
The delay between declaring a new governance address and it being confirmed

### txSenders
```solidity
mapping(address => bool) public txSenders
```
Mapping of MPC addresses to their validity

### senders
```solidity
address[] public senders
```
Array of all txSender addresses

## Modifiers

### onlyGov
```solidity
modifier onlyGov()
```
Modifier to restrict access to governance or C3Caller.

**Dev:** Reverts if the caller is neither governance address nor C3Caller

## Functions

### gov
```solidity
function gov() public view returns (address)
```
Get the current governance address.

**Returns:**
- `address`: The current governance address (new or old based on effective time)

### changeGov
```solidity
function changeGov(address newGov_) external onlyGov
```
Change the governance address. The new governance address will be valid after delay.

**Parameters:**
- `newGov_`: The new governance address

**Dev:** Reverts if the new governance address is zero. Only governance or C3Caller can call this function

### setDelay
```solidity
function setDelay(uint256 _delay) external onlyGov
```
Set the delay period for governance changes.

**Parameters:**
- `_delay`: The new delay period in seconds

**Dev:** Only governance or C3Caller can call this function

### addTxSender
```solidity
function addTxSender(address _txSender) external onlyGov
```
Add an MPC address that can call functions that should be targeted by C3Caller execute.

**Parameters:**
- `_txSender`: The MPC address to add

**Dev:** Only governance or C3Caller can call this function

### disableTxSender
```solidity
function disableTxSender(address _txSender) external onlyGov
```
Disable an MPC address, which will no longer be able to call functions targeted by C3Caller execute.

**Parameters:**
- `_txSender`: The MPC address to disable

**Dev:** Only governance or C3Caller can call this function

### doGov
```solidity
function doGov(string memory _to, string memory _toChainID, bytes memory _data) external onlyGov
```
Execute an arbitrary cross-chain operation on a single target.

**Parameters:**
- `_to`: The target address on the destination network
- `_toChainID`: The destination chain ID
- `_data`: The calldata to execute

**Dev:** Only governance or C3Caller can call this function

### doGovBroadcast
```solidity
function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data) external onlyGov
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
function isValidSender(address _txSender) external view override(IC3CallerDApp, C3CallerDApp) returns (bool)
```
Check if an address is a valid MPC address executor for this DApp.

**Parameters:**
- `_txSender`: The address to check

**Returns:**
- `bool`: True if the address is a valid sender, false otherwise

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

This contract provides governance functionality for DApps