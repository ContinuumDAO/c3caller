// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./C3GovClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract C3Governor is C3GovClient {
    using Strings for *;

    struct Proposal {
        bytes[] proposalData;
        bool[] failed;
    }

    event NewProposal(bytes32 indexed uuid);

    // TODO add isGov bool
    event C3GovernorLog(
        bytes32 indexed nonce,
        uint256 indexed toChainID,
        string to,
        bytes toData
    );

    mapping(bytes32 => Proposal) internal proposal;

    constructor() {
        initGov(msg.sender);
    }

    function chainID() internal view returns (uint256) {
        return block.chainid;
    }

    // TODO gen nonce
    function sendParams(bytes memory _data, bytes32 _nonce) external onlyGov {
        require(_data.length > 0, "C3Governor: No data to sendParams");

        proposal[_nonce].proposalData.push(_data);
        proposal[_nonce].failed.push(false);

        emit NewProposal(_nonce);

        _c3gov(_nonce, 0);
    }

    function sendMultiParams(
        bytes[] memory _data,
        bytes32 _nonce
    ) external onlyGov {
        require(_data.length > 0, "C3Governor: No data to sendParams");

        for (uint256 index = 0; index < _data.length; index++) {
            require(
                _data[index].length > 0,
                "C3Governor: No data passed to sendParams"
            );
            proposal[_nonce].proposalData.push(_data[index]);
            proposal[_nonce].failed.push(false);

            _c3gov(_nonce, index);
        }
        emit NewProposal(_nonce);
    }

    // Anyone can resend one of the cross chain calls in proposalId if it failed
    function doGov(bytes32 _nonce, uint256 offset) external {
        require(
            offset < proposal[_nonce].proposalData.length,
            "C3Governor: Reading beyond the length of the offset array"
        );
        require(
            proposal[_nonce].failed[offset] == false,
            "C3Governor: Do not resend if it did not fail"
        );

        _c3gov(_nonce, offset);
    }

    function getProposalData(
        bytes32 _nonce,
        uint256 offset
    ) external view returns (bytes memory, bool) {
        return (
            proposal[_nonce].proposalData[offset],
            proposal[_nonce].failed[offset]
        );
    }

    function _c3gov(bytes32 _nonce, uint256 offset) internal {
        uint256 chainId;
        string memory target;
        bytes memory remoteData;

        bytes memory rawData = proposal[_nonce].proposalData[offset];
        // TODO add flag which config using gov to send or operator
        (chainId, target, remoteData) = abi.decode(
            rawData,
            (uint256, string, bytes)
        );

        if (chainId == chainID()) {
            address _to = toAddress(target);
            (bool success, ) = _to.call(remoteData);
            if (success) {
                proposal[_nonce].failed[offset] = true;
            }
        } else {
            proposal[_nonce].failed[offset] = true;
            emit C3GovernorLog(_nonce, chainId, target, remoteData);
        }
    }

    function hexStringToAddress(
        string memory s
    ) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0); // length must be even
        bytes memory r = new bytes(ss.length / 2);
        for (uint i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(
                fromHexChar(uint8(ss[2 * i])) *
                    16 +
                    fromHexChar(uint8(ss[2 * i + 1]))
            );
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
            tempAddress := div(
                mload(add(add(_bytes, 0x20), 1)),
                0x1000000000000000000000000
            )
        }
        return tempAddress;
    }

    function version() public pure returns (uint256) {
        return (1);
    }
}
