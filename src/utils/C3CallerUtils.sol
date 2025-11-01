// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

/**
 * @title C3ErrorParam
 * @dev Enumeration of error parameters used throughout the C3 protocol
 * Provides standardized error parameter types for consistent error handling
 * This allows reuse of errors to describe different error situations
 */
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
    Gov,
    PendingGov
}

/**
 * @title C3CallerUtils
 * @notice Utility library for the C3 protocol, providing helper functions
 * for address conversion, hex string parsing, and data type conversions.
 *
 * This library contains utility functions that are commonly used across
 * the C3 protocol for data manipulation and validation.
 *
 * @author @potti ContinuumDAO
 */
library C3CallerUtils {
    /// @notice Error thrown when accessing data out of bounds
    error C3CallerUtils_OutOfBounds();

    /**
     * @dev Convert a hex string to bytes
     * @param _s The hex string to convert
     * @return The converted bytes
     * @notice The input string length must be even
     */
    function hexStringToAddress(string memory _s) internal pure returns (bytes memory) {
        bytes memory _ss = bytes(_s);
        bytes memory _r = new bytes(_ss.length / 2);
        for (uint256 _i = 0; _i < _ss.length / 2; ++_i) {
            _r[_i] = bytes1(fromHexChar(uint8(_ss[2 * _i])) * 16 + fromHexChar(uint8(_ss[2 * _i + 1])));
        }

        return _r;
    }

    /**
     * @notice Convert a hex character to its decimal value
     * @param _c The hex character to convert
     * @return The decimal value of the hex character
     * @dev Supports both uppercase and lowercase hex characters
     */
    function fromHexChar(uint8 _c) internal pure returns (uint8) {
        if (bytes1(_c) >= bytes1("0") && bytes1(_c) <= bytes1("9")) {
            return _c - uint8(bytes1("0"));
        }
        if (bytes1(_c) >= bytes1("a") && bytes1(_c) <= bytes1("f")) {
            return 10 + _c - uint8(bytes1("a"));
        }
        if (bytes1(_c) >= bytes1("A") && bytes1(_c) <= bytes1("F")) {
            return 10 + _c - uint8(bytes1("A"));
        }
        return 0;
    }

    /**
     * @notice Convert a hex string to an address
     * @param _s The hex string representing an address
     * @return The converted address
     * @dev The hex string must be at least 21 bytes (20 bytes for address + 1 byte prefix)
     * @dev Reverts if the input is too short to represent a valid address
     */
    function toAddress(string memory _s) internal pure returns (address) {
        bytes memory _bytes = hexStringToAddress(_s);
        if (_bytes.length < 21) {
            revert C3CallerUtils_OutOfBounds();
        }
        address _tempAddress;

        assembly {
            _tempAddress := div(mload(add(add(_bytes, 0x20), 1)), 0x1000000000000000000000000)
        }
        return _tempAddress;
    }
}
