# C3GovernorUpgradeable

This contract acts as a wrapper for C3GovernDApp, for the purpose of cross-chain governance. A client is deployed on every applicable network and clients communicate with one another to send/receive data. The most typical use case is with OpenZeppelin's Governor. A successful proposal can have as one of its actions a call to this contract's function `sendParams` with an array of target contracts, their chain IDs, and calldata. Included as a feature is the ability to retry reverted transactions, mirroring the execute function in Governor. If one or more actions from a proposal fail, anyone may retry them until they succeed, obviating the need for a duplicate proposal. This contract provides the same functionality as C3Caller but with upgradeable capabilities using the UUPS (Universal Upgradeable Proxy Standard) pattern.

## Constructor

```solidity
constructor()
```

Disable initializers.

## State Variables

### VERSION
```solidity
uint256 public constant VERSION = 1
```
The current version of C3Governor

### proposalRegistered
```solidity
mapping(uint256 => bool) public proposalRegistered
```
A registry of active proposal IDs (or a custom nonce)

### peer
```solidity
mapping(string => string) public peer
```
The C3Governor clients deployed to destination networks

### failed
```solidity
mapping(uint256 => mapping(uint256 => Proposal)) public failed
```
Actions that have failed on the destination network have their data stored until they are retried

## Functions

### initialize
```solidity
function initialize(address _gov, address _c3CallerProxy, address _txSender, uint256 _dappID) external initializer
```
Initialize C3GovernorUpgradeable.

**Parameters:**
- `_gov`: Deployed Governor contract (or admin of choice)
- `_c3CallerProxy`: The C3Caller deployed instance
- `_txSender`: The MPC address that is whitelisted to execute incoming operations
- `_dappID`: The DApp ID of this C3CallerDApp

### setPeer
```solidity
function setPeer(string memory _chainIdStr, string memory _peerStr) external onlyGov
```
Sets the peer address for a given chain ID.

**Parameters:**
- `_chainIdStr`: The chain ID to set
- `_peerStr`: The deployed peer client on that network

**Dev:** Chain ID and peer address are encoded as a string to allow non-EVM data

### doGov
```solidity
function doGov(uint256 _nonce, uint256 _index) external
```
Allow anyone to retry a given transaction of a given proposal that reverted on another network.

**Parameters:**
- `_nonce`: The proposal ID of the transaction
- `_index`: The index of the transaction in the proposal

**Dev:** Some transactions in a given proposal may fail, but this does not stop other transactions in the proposal from succeeding. This should be anticipated in the target contract architecture

### sendParams
```solidity
function sendParams(
    uint256 _nonce,
    string[] memory _targetStrs,
    string[] memory _toChainIdStrs,
    bytes[] memory _calldatas
) external onlyGov
```
Entry point for a proposal to be executed on another network (called by Governor). This call should be encoded in a Governor proposal. Each proposal may only be initiated once.

**Parameters:**
- `_nonce`: The ID of the proposal (can only be done once per proposal)
- `_targetStrs`: The array of addresses that will be called on the destination network
- `_toChainIdStrs`: The array of chain IDs for each transaction
- `_calldatas`: The array of calldata that will be called on the corresponding address

**Dev:** Arrays must be the same length, non-zero values. Chain IDs must be registered peers

### receiveParams
```solidity
function receiveParams(
    uint256 _nonce,
    uint256 _index,
    string memory _targetStr,
    string memory _toChainIdStr,
    bytes memory _calldata
) external onlyCaller returns (bytes memory)
```
Entry point on the destination network for calls that were initiated with `sendParams`.

**Parameters:**
- `_nonce`: The ID of the proposal from the source network
- `_index`: The index of the transaction on the proposal
- `_targetStr`: The address of the contract to call on the destination network
- `_toChainIdStr`: The chain ID of the destination network (the network this function is called on)
- `_calldata`: The data to call on the corresponding contract address

**Returns:**
- `bytes`: The result of the call

**Dev:** Called by C3Caller execute. If the transaction reverts, it will be routed to fallback on source chain

## Internal Functions

### _sendParams
```solidity
function _sendParams(
    uint256 _nonce,
    uint256 _index,
    string memory _target,
    string memory _toChainIdStr,
    bytes memory _calldata
) internal
```
Internal handler called by `sendParams` and `doGov`.

**Parameters:**
- `_nonce`: The ID of the proposal
- `_index`: The index of the transaction on the proposal
- `_target`: The address of the contract to call on the destination network
- `_toChainIdStr`: The chain ID of the destination network
- `_calldata`: The data to execute on the corresponding contract address

### _c3Fallback
```solidity
function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason) internal override returns (bool)
```
Called by C3Caller on the source network in the event of a reverted transaction.

**Parameters:**
- `_selector`: The 4-byte selector of the transaction (necessarily the selector of `receiveParams`)
- `_data`: The revert data (passed in as the arguments to the failed `receiveParams`)
- `_reason`: The revert data of the failed `receiveParams`(encoded in the custom error C3Governor_ExecFailed)

**Returns:**
- `bool`: True if the fallback was handled

**Dev:** This marks the transaction as eligible to retry using `doGov` by saving its target, chain ID and calldata

### _authorizeUpgrade
```solidity
function _authorizeUpgrade(address newImplementation) internal virtual override onlyGov
```
Internal function to authorize upgrades.

**Parameters:**
- `newImplementation`: The new implementation address

**Dev:** Only Governor can authorize upgrades

## Events

### C3GovernorCall
```solidity
event C3GovernorCall(uint256 indexed nonce, uint256 indexed index, string targetStr, string toChainIdStr, bytes calldata)
```

### C3GovernorExec
```solidity
event C3GovernorExec(uint256 indexed nonce, uint256 indexed index, string targetStr, string toChainIdStr, bytes calldata)
```

### C3GovernorFallback
```solidity
event C3GovernorFallback(uint256 indexed nonce, uint256 indexed index, string targetStr, string toChainIdStr, bytes calldata, bytes reason)
```

## Errors

### C3Governor_InvalidProposal
```solidity
error C3Governor_InvalidProposal(uint256)
```

### C3Governor_HasNotFailed
```solidity
error C3Governor_HasNotFailed()
```

### C3Governor_InvalidLength
```solidity
error C3Governor_InvalidLength(C3ErrorParam)
```

### C3Governor_LengthMismatch
```solidity
error C3Governor_LengthMismatch(C3ErrorParam, C3ErrorParam)
```

### C3Governor_UnsupportedChainID
```solidity
error C3Governor_UnsupportedChainID(string)
```

### C3Governor_ExecFailed
```solidity
error C3Governor_ExecFailed(bytes)
```

## Structs

### Proposal
```solidity
struct Proposal {
    string target;
    string toChainId;
    bytes data;
}
```

## Authors

@patrickcure, @potti, @Selqui (ContinuumDAO)

## Dev

This contract is the upgradeable version of the cross-chain governance client