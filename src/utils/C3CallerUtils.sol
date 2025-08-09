// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

/**
 * @title C3ErrorParam
 * @dev Enumeration of error parameters used throughout the C3 protocol
 * Provides standardized error parameter types for consistent error handling
 */
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

/**
 * @title C3CallerUtils
 * @dev Utility library for C3Caller contract providing helper functions
 * for address conversion, hex string parsing, and data type conversions.
 * 
 * This library contains utility functions that are commonly used across
 * the C3 protocol for data manipulation and validation.
 * 
 * @notice Provides utility functions for cross-chain operations
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
     * @dev Convert a hex character to its decimal value
     * @param _c The hex character to convert
     * @return The decimal value of the hex character
     * @notice Supports both uppercase and lowercase hex characters
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
     * @dev Convert a hex string to an address
     * @param _s The hex string representing an address
     * @return The converted address
     * @notice The hex string must be at least 21 bytes (20 bytes for address + 1 byte prefix)
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

    /**
     * @dev Convert bytes to uint256 with validation
     * @param bs The bytes to convert
     * @return ok True if conversion was successful
     * @return value The converted uint256 value
     * @notice Supports bytes lengths of 1, 2, 4, 8, 16, and 32
     */
    function _toUint(bytes memory bs) internal pure returns (bool, uint256) {
        if (bs.length == 0) {
            return (false, 0);
        }
        if (bs.length == 1) {
            return (true, uint256(uint8(bs[0])));
        }
        if (bs.length == 2) {
            return (true, uint256(uint16(bytes2(bs))));
        }
        if (bs.length == 4) {
            return (true, uint256(uint32(bytes4(bs))));
        }
        if (bs.length == 8) {
            return (true, uint256(uint64(bytes8(bs))));
        }
        if (bs.length == 16) {
            return (true, uint256(uint128(bytes16(bs))));
        }
        if (bs.length == 32) {
            return (true, uint256(bytes32(bs)));
        }
        return (false, 0);
    }
}
