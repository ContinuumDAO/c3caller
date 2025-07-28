// SPDX-License-Identifier: BSL-1.1

pragma solidity ^0.8.22;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3GovernDapp } from "./C3GovernDapp.sol";
import { IC3Governor } from "./IC3Governor.sol";

contract C3Governor is IC3Governor, C3GovernDapp {
    using Strings for *;

    struct Proposal {
        bytes[] data;
        bool[] hasFailed;
    }

    mapping(bytes32 => Proposal) private _proposal;
    bytes32 public proposalId;

    // TODO: make the upgradeable contract work with this non-upgradeable contract
    constructor(address _gov, address _c3CallerProxy, address _txSender, uint256 _dappID) {
        __C3GovernDapp_init(_gov, _c3CallerProxy, _txSender, _dappID);
    }

    function chainID() internal view returns (uint256) {
        return block.chainid;
    }

    // TODO: gen nonce
    function sendParams(bytes memory _data, bytes32 _nonce) external /*onlyGov*/ {
        require(_data.length > 0, "C3Governor: No data to sendParams");

        _proposal[_nonce].data.push(_data);
        _proposal[_nonce].hasFailed.push(false);

        emit NewProposal(_nonce);

        _c3gov(_nonce, 0);
    }

    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external /*onlyGov*/ {
        require(_data.length > 0, "C3Governor: No data to sendParams");

        for (uint256 index = 0; index < _data.length; index++) {
            require(_data[index].length > 0, "C3Governor: No data passed to sendParams");
            _proposal[_nonce].data.push(_data[index]);
            _proposal[_nonce].hasFailed.push(false);

            _c3gov(_nonce, index);
        }
        emit NewProposal(_nonce);
    }

    // Anyone can resend one of the cross chain calls in proposalId if it failed
    function doGov(bytes32 _nonce, uint256 offset) external {
        require(offset < _proposal[_nonce].data.length, "C3Governor: Reading beyond the length of the offset array");
        require(_proposal[_nonce].hasFailed[offset] == false, "C3Governor: Do not resend if it did not fail");

        _c3gov(_nonce, offset);
    }

    function getProposalData(bytes32 _nonce, uint256 offset) external view returns (bytes memory, bool) {
        return (_proposal[_nonce].data[offset], _proposal[_nonce].hasFailed[offset]);
    }

    function _c3gov(bytes32 _nonce, uint256 offset) internal {
        uint256 chainId;
        string memory target;
        bytes memory remoteData;

        bytes memory rawData = _proposal[_nonce].data[offset];
        // TODO add flag which config using gov to send or operator
        (chainId, target, remoteData) = abi.decode(rawData, (uint256, string, bytes));

        if (chainId == chainID()) {
            address _to = toAddress(target);
            (bool success,) = _to.call(remoteData);
            if (success) {
                _proposal[_nonce].hasFailed[offset] = true;
            }
        } else {
            _proposal[_nonce].hasFailed[offset] = true;
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

    function _c3Fallback(bytes4 selector, bytes calldata data, bytes calldata reason)
        internal
        override
        returns (bool)
    {
        uint256 len = proposalLength();

        _proposal[proposalId].hasFailed[len - 1] = true;

        emit LogFallback(selector, data, reason);
        return true;
    }

    // The number of cross chain invocations in proposalId
    function proposalLength() public view returns (uint256) {
        uint256 len = _proposal[proposalId].data.length;
        return (len);
    }
}
