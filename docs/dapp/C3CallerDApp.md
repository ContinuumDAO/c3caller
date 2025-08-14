# C3CallerDApp

## Overview

C3CallerDApp is an abstract base contract for DApps in the C3 protocol. This contract provides the foundation for DApps to interact with the C3Caller system and handle cross-chain operations.

### Key Features

- C3Caller proxy integration
- DApp identifier management
- Cross-chain call initiation
- Fallback mechanism for failed operations
- Context retrieval for cross-chain operations

**Note:** This contract serves as the base for all C3 DApps

## Contract Details

- **Contract Name:** `C3CallerDApp`
- **Type:** Abstract Contract
- **Implements:** `IC3CallerDApp`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## State Variables

### `c3CallerProxy`
```solidity
address public c3CallerProxy
```
The C3Caller proxy address.

### `dappID`
```solidity
uint256 public dappID
```
The DApp identifier.

## Constructor

### `constructor(address _c3CallerProxy, uint256 _dappID)`
Initializes the C3CallerDApp contract.

**Parameters:**
- `_c3CallerProxy` (address): The C3Caller proxy address
- `_dappID` (uint256): The DApp identifier

## Modifiers

### `onlyCaller`
Restricts access to C3Caller only.

**Notes:**
- Reverts if the caller is not the C3Caller

## External Functions

### `c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason)`
Handle fallback calls from C3Caller.

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_data` (bytes): The call data
- `_reason` (bytes): The failure reason

**Returns:**
- `bool`: True if the fallback was handled successfully

**Modifiers:**
- `onlyCaller`

**Notes:**
- Only C3Caller can call this function
- Validates that the DApp ID matches
- Handles function selector extraction from calldata
- If data length is less than 4 bytes, calls `_c3Fallback` with selector 0
- Otherwise, extracts the first 4 bytes as selector and passes remaining data

### `isValidSender(address _txSender)`
Check if an address is a valid sender for this DApp.

**Parameters:**
- `_txSender` (address): The address to check

**Returns:**
- `bool`: True if the address is a valid sender

**Notes:**
- This function must be implemented by derived contracts

## Internal Functions

### `_isCaller(address _addr)`
Internal function to check if an address is the C3Caller.

**Parameters:**
- `_addr` (address): The address to check

**Returns:**
- `bool`: True if the address is the C3Caller

**Notes:**
- Virtual function that can be overridden by derived contracts
- Calls `IC3Caller(c3CallerProxy).isCaller(_addr)` to verify the address

### `_c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)`
Internal function to handle fallback calls.

**Parameters:**
- `_selector` (bytes4): The function selector
- `_data` (bytes): The call data
- `_reason` (bytes): The failure reason

**Returns:**
- `bool`: True if the fallback was handled successfully

**Notes:**
- This function must be implemented by derived contracts

### `_c3call(string memory _to, string memory _toChainID, bytes memory _data)`
Internal function to initiate a cross-chain call.

**Parameters:**
- `_to` (string): The target address on the destination chain
- `_toChainID` (string): The destination chain identifier
- `_data` (bytes): The calldata to execute

**Notes:**
- Virtual function that can be overridden by derived contracts
- Calls the C3Caller proxy with empty extra data
- Uses the contract's `dappID` for the cross-chain call

### `_c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra)`
Internal function to initiate a cross-chain call with extra data.

**Parameters:**
- `_to` (string): The target address on the destination chain
- `_toChainID` (string): The destination chain identifier
- `_data` (bytes): The calldata to execute
- `_extra` (bytes): Additional data for the cross-chain call

**Notes:**
- Virtual function that can be overridden by derived contracts
- Uses the contract's `dappID` for the cross-chain call

### `_c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data)`
Internal function to initiate cross-chain broadcasts.

**Parameters:**
- `_to` (string[]): Array of target addresses on destination chains
- `_toChainIDs` (string[]): Array of destination chain identifiers
- `_data` (bytes): The calldata to execute on destination chains

**Notes:**
- Virtual function that can be overridden by derived contracts
- Uses the contract's `dappID` for the cross-chain broadcast

### `_context()`
Internal function to get the current cross-chain context.

**Returns:**
- `uuid` (bytes32): The UUID of the current cross-chain operation
- `fromChainID` (string): The source chain identifier
- `sourceTx` (string): The source transaction hash

**Notes:**
- Virtual function that can be overridden by derived contracts
- Calls `IC3Caller(c3CallerProxy).context()` to retrieve the current context

## Usage Examples

### Implementing a Derived Contract
```solidity
contract MyDApp is C3CallerDApp {
    constructor(address _c3CallerProxy, uint256 _dappID) 
        C3CallerDApp(_c3CallerProxy, _dappID) 
    {}

    function isValidSender(address _txSender) external view override returns (bool) {
        // Implement your sender validation logic
        return _txSender == address(0x123); // Example
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason) 
        internal override returns (bool) 
    {
        // Implement your fallback logic
        return true;
    }

    function initiateCrossChainCall() external {
        _c3call(
            "0x1234567890123456789012345678901234567890",
            "1", // Ethereum mainnet
            abi.encodeWithSelector(this.someFunction.selector, param1, param2)
        );
    }
}
```

## Security Considerations

1. **Access Control**: Only the C3Caller proxy can execute fallback functions
2. **DApp ID Validation**: Ensures operations are performed on the correct DApp
3. **Sender Validation**: Derived contracts must implement proper sender validation
4. **Fallback Handling**: Proper fallback logic must be implemented to handle failed operations

## Dependencies

- `IC3Caller.sol`
- `IC3CallerDApp.sol`
- `C3ErrorParam` from `C3CallerUtils.sol`
