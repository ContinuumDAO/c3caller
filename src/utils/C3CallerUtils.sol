// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

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
    Target,
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

library C3CallerUtils {
    error C3CallerUtils_OutOfBounds();

    function hexStringToAddress(string memory _s) internal pure returns (bytes memory) {
        bytes memory _ss = bytes(_s);
        // require(ss.length % 2 == 0); // length must be even
        bytes memory _r = new bytes(_ss.length / 2);
        for (uint256 _i = 0; _i < _ss.length / 2; ++_i) {
            _r[_i] = bytes1(fromHexChar(uint8(_ss[2 * _i])) * 16 + fromHexChar(uint8(_ss[2 * _i + 1])));
        }

        return _r;
    }

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

    function toAddress(string memory _s) internal pure returns (address) {
        bytes memory _bytes = hexStringToAddress(_s);
        // require(_bytes.length >= 1 + 20, "toAddress_outOfBounds");
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
