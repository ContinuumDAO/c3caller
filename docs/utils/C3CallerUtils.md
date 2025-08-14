# C3CallerUtils

## Overview

C3CallerUtils is a utility library for C3Caller contract providing helper functions for address conversion, hex string parsing, and data type conversions. This library contains utility functions that are commonly used across the C3 protocol for data manipulation and validation.

**Note:** Provides utility functions for cross-chain operations

## Library Details

- **Library Name:** `C3CallerUtils`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## C3ErrorParam Enum

The `C3ErrorParam` enum provides standardized error parameter types for consistent error handling throughout the C3 protocol.

```solidity
enum C3ErrorParam {
    ChainID,        /// Chain identifier parameter
    Calldata,       /// Calldata parameter
    DAppID,         /// DApp identifier parameter
    FeePerByte,     /// Fee per byte parameter
    AppDomain,      /// Application domain parameter
    Email,          /// Email parameter
    Address,        /// Address parameter
    PubKey,         /// Public key parameter
    Token,          /// Token parameter
    Target,         /// Target parameter
    Sender,         /// Sender parameter
    C3Caller,       /// C3Caller parameter
    To,             /// To parameter
    Valid,          /// Valid parameter
    Admin,          /// Admin parameter
    GovOrAdmin,     /// Governance or admin parameter
    GovOrOperator,  /// Governance or operator parameter
    GovOrC3Caller,  /// Governance or C3Caller parameter
    Operator,       /// Operator parameter
    Gov             /// Governance parameter
}
```

## Errors

### `C3CallerUtils_OutOfBounds`
Thrown when accessing data out of bounds.

```solidity
error C3CallerUtils_OutOfBounds();
```

## Functions

### `hexStringToAddress(string memory _s)`
Convert a hex string to bytes.

**Parameters:**
- `_s` (string): The hex string to convert

**Returns:**
- `bytes`: The converted bytes

**Notes:**
- The input string length must be even
- Supports both uppercase and lowercase hex characters

### `fromHexChar(uint8 _c)`
Convert a hex character to its decimal value.

**Parameters:**
- `_c` (uint8): The hex character to convert

**Returns:**
- `uint8`: The decimal value of the hex character

**Notes:**
- Supports both uppercase and lowercase hex characters
- Returns 0 for invalid hex characters

### `toAddress(string memory _s)`
Convert a hex string to an address.

**Parameters:**
- `_s` (string): The hex string representing an address

**Returns:**
- `address`: The converted address

**Notes:**
- The hex string must be at least 21 bytes (20 bytes for address + 1 byte prefix)
- Reverts if the input is too short to represent a valid address

### `toUint(bytes memory bs)`
Convert bytes to uint256 with validation.

**Parameters:**
- `bs` (bytes): The bytes to convert

**Returns:**
- `ok` (bool): True if conversion was successful
- `value` (uint256): The converted uint256 value

**Notes:**
- Supports bytes lengths of 1, 2, 4, 8, 16, and 32
- Returns (false, 0) for unsupported lengths or empty input

## Usage Examples

### Hex String to Address Conversion
```solidity
// Convert hex string to address
string memory hexString = "0x1234567890123456789012345678901234567890";
address convertedAddress = C3CallerUtils.toAddress(hexString);

// Convert hex string to bytes
bytes memory hexBytes = C3CallerUtils.hexStringToAddress(hexString);
```

### Hex Character Conversion
```solidity
// Convert hex characters to decimal values
uint8 decimal1 = C3CallerUtils.fromHexChar(uint8(bytes1("A"))); // Returns 10
uint8 decimal2 = C3CallerUtils.fromHexChar(uint8(bytes1("f"))); // Returns 15
uint8 decimal3 = C3CallerUtils.fromHexChar(uint8(bytes1("5"))); // Returns 5
```

### Bytes to Uint Conversion
```solidity
// Convert different byte lengths to uint256
bytes memory oneByte = hex"01";
(bool ok1, uint256 value1) = C3CallerUtils.toUint(oneByte); // (true, 1)

bytes memory fourBytes = hex"00000001";
(bool ok2, uint256 value2) = C3CallerUtils.toUint(fourBytes); // (true, 1)

bytes memory thirtyTwoBytes = hex"0000000000000000000000000000000000000000000000000000000000000001";
(bool ok3, uint256 value3) = C3CallerUtils.toUint(thirtyTwoBytes); // (true, 1)

// Invalid length
bytes memory invalidBytes = hex"000000";
(bool ok4, uint256 value4) = C3CallerUtils.toUint(invalidBytes); // (false, 0)
```

### Error Parameter Usage
```solidity
// Using C3ErrorParam in custom errors
error MyCustomError(C3ErrorParam param);

// Throwing errors with specific parameters
if (someCondition) {
    revert MyCustomError(C3ErrorParam.Address);
}

if (anotherCondition) {
    revert MyCustomError(C3ErrorParam.Calldata);
}
```

## Supported Data Types

### Hex String Conversion
- **Input**: Hex string (e.g., "0x1234567890abcdef")
- **Output**: Bytes or address
- **Requirements**: Even length for bytes, minimum 21 bytes for address

### Hex Character Conversion
- **Input**: Single hex character (0-9, a-f, A-F)
- **Output**: Decimal value (0-15)
- **Case**: Case-insensitive

### Bytes to Uint Conversion
- **Supported Lengths**: 1, 2, 4, 8, 16, 32 bytes
- **Output**: (bool success, uint256 value)
- **Validation**: Returns (false, 0) for unsupported lengths

## Security Considerations

1. **Input Validation**: Functions validate input parameters to prevent errors
2. **Bounds Checking**: Address conversion checks for minimum length requirements
3. **Type Safety**: Bytes to uint conversion only supports specific lengths
4. **Error Handling**: Clear error messages for invalid inputs

## Dependencies

- No external dependencies
- Pure functions for gas efficiency
