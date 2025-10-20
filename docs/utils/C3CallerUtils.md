# C3CallerUtils

Utility library for the C3 protocol, providing helper functions for address conversion, hex string parsing, and data type conversions.

This library contains utility functions that are commonly used across the C3 protocol for data manipulation and validation.

## C3ErrorParam Enum

```solidity
enum C3ErrorParam {
    ChainID,
    Calldata,
    DAppID,
    FeePerByte,
    AppDomain,
    Email,
    Address,
    PubKey,
    Token,
    Sender,
    C3Caller,
    To,
    Valid,
    Admin,
    GovOrAdmin,
    GovOrOperator,
    GovOrC3Caller,
    Operator,
    Gov
}
```

Enumeration of error parameters used throughout the C3 protocol. Provides standardized error parameter types for consistent error handling. This allows reuse of errors to describe different error situations.

## Functions

### hexStringToAddress
```solidity
function hexStringToAddress(string memory _s) internal pure returns (bytes memory)
```
Convert a hex string to bytes.

**Parameters:**
- `_s`: The hex string to convert

**Returns:**
- `bytes`: The converted bytes

**Notice:** The input string length must be even

### fromHexChar
```solidity
function fromHexChar(uint8 _c) internal pure returns (uint8)
```
Convert a hex character to its decimal value.

**Parameters:**
- `_c`: The hex character to convert

**Returns:**
- `uint8`: The decimal value of the hex character

**Dev:** Supports both uppercase and lowercase hex characters

### toAddress
```solidity
function toAddress(string memory _s) internal pure returns (address)
```
Convert a hex string to an address.

**Parameters:**
- `_s`: The hex string representing an address

**Returns:**
- `address`: The converted address

**Dev:** The hex string must be at least 21 bytes (20 bytes for address + 1 byte prefix). Reverts if the input is too short to represent a valid address

## Errors

### C3CallerUtils_OutOfBounds
```solidity
error C3CallerUtils_OutOfBounds()
```
Error thrown when accessing data out of bounds

## Author

@potti ContinuumDAO