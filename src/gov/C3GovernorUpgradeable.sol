// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3GovClientUpgradeable } from "./C3GovClientUpgradeable.sol";
import { IC3Governor } from "./IC3Governor.sol";

contract C3GovernorUpgradeable is IC3Governor, C3GovClientUpgradeable {
    using Strings for *;

    struct Proposal {
        bytes[] data;
        bool[] hasFailed;
    }

    /// @custom:storage-location erc7201:c3caller.storage.C3Governor
    struct C3GovernorStorage {
        mapping(bytes32 => Proposal) proposal;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3Governor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3GovernorStorageLocation =
        0xaeb833df2c95c6ad4fba79fb2d58614f4067e4abf9a242627c00cf8ebb346000;

    function _getC3GovernorStorage() private pure returns (C3GovernorStorage storage $) {
        assembly {
            $.slot := C3GovernorStorageLocation
        }
    }

    function __C3Governor_init() internal initializer {
        __C3GovClient_init(msg.sender);
    }

    function chainID() internal view returns (uint256) {
        return block.chainid;
    }

    // TODO: gen nonce
    function sendParams(bytes memory _data, bytes32 _nonce) external onlyGov {
        require(_data.length > 0, "C3Governor: No data to sendParams");

        C3GovernorStorage storage $ = _getC3GovernorStorage();
        $.proposal[_nonce].data.push(_data);
        $.proposal[_nonce].hasFailed.push(false);

        emit NewProposal(_nonce);

        _c3gov(_nonce, 0);
    }

    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external onlyGov {
        require(_data.length > 0, "C3Governor: No data to sendParams");

        for (uint256 index = 0; index < _data.length; index++) {
            require(_data[index].length > 0, "C3Governor: No data passed to sendParams");
            C3GovernorStorage storage $ = _getC3GovernorStorage();
            $.proposal[_nonce].data.push(_data[index]);
            $.proposal[_nonce].hasFailed.push(false);

            _c3gov(_nonce, index);
        }
        emit NewProposal(_nonce);
    }

    // Anyone can resend one of the cross chain calls in proposalId if it failed
    function doGov(bytes32 _nonce, uint256 offset) external {
        C3GovernorStorage storage $ = _getC3GovernorStorage();
        require(offset < $.proposal[_nonce].data.length, "C3Governor: Reading beyond the length of the offset array");
        require($.proposal[_nonce].hasFailed[offset] == false, "C3Governor: Do not resend if it did not fail");

        _c3gov(_nonce, offset);
    }

    function getProposalData(bytes32 _nonce, uint256 offset) external view returns (bytes memory, bool) {
        C3GovernorStorage storage $ = _getC3GovernorStorage();
        return ($.proposal[_nonce].data[offset], $.proposal[_nonce].hasFailed[offset]);
    }

    function _c3gov(bytes32 _nonce, uint256 offset) internal {
        C3GovernorStorage storage $ = _getC3GovernorStorage();

        uint256 chainId;
        string memory target;
        bytes memory remoteData;

        bytes memory rawData = $.proposal[_nonce].data[offset];
        // TODO add flag which config using gov to send or operator
        (chainId, target, remoteData) = abi.decode(rawData, (uint256, string, bytes));

        if (chainId == chainID()) {
            address _to = toAddress(target);
            (bool success,) = _to.call(remoteData);
            if (success) {
                $.proposal[_nonce].hasFailed[offset] = true;
            }
        } else {
            $.proposal[_nonce].hasFailed[offset] = true;
            emit C3GovernorLog(_nonce, chainId, target, remoteData);
        }
    }

    function hexStringToAddress(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0); // length must be even
        bytes memory r = new bytes(ss.length / 2);
        for (uint256 i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(fromHexChar(uint8(ss[2 * i])) * 16 + fromHexChar(uint8(ss[2 * i + 1])));
        }

        return r;
    }

    function fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
            return 10 + c - uint8(bytes1("A"));
        }
        return 0;
    }

    function toAddress(string memory s) internal pure returns (address) {
        bytes memory _bytes = hexStringToAddress(s);
        require(_bytes.length >= 1 + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), 1)), 0x1000000000000000000000000)
        }
        return tempAddress;
    }

    function version() public pure returns (uint256) {
        return (1);
    }
}
