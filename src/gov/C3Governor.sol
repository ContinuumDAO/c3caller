// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3GovernDapp } from "./C3GovernDapp.sol";
import { IC3Governor } from "./IC3Governor.sol";
import {Uint, C3CallerUtils} from "../utils/C3CallerUtils.sol";

contract C3Governor is IC3Governor, C3GovernDapp {
    using Strings for *;
    using C3CallerUtils for string;

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
        // require(_data.length > 0, "C3Governor: No data to sendParams");
        if (_data.length == 0) revert C3Governor_InvalidLength(Uint.Calldata);

        _proposal[_nonce].data.push(_data);
        _proposal[_nonce].hasFailed.push(false);

        emit NewProposal(_nonce);

        _c3gov(_nonce, 0);
    }

    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external /*onlyGov*/ {
        // require(_data.length > 0, "C3Governor: No data to sendParams");
        if (_data.length == 0) revert C3Governor_InvalidLength(Uint.Calldata);

        for (uint256 index = 0; index < _data.length; index++) {
            // require(_data[index].length > 0, "C3Governor: No data passed to sendParams");
            if (_data.length == 0) revert C3Governor_InvalidLength(Uint.Calldata);
            _proposal[_nonce].data.push(_data[index]);
            _proposal[_nonce].hasFailed.push(false);

            _c3gov(_nonce, index);
        }
        emit NewProposal(_nonce);
    }

    // Anyone can resend one of the cross chain calls in proposalId if it failed
    function doGov(bytes32 _nonce, uint256 offset) external {
        // require(offset < _proposal[_nonce].data.length, "C3Governor: Reading beyond the length of the offset array");
        if (offset >= _proposal[_nonce].data.length) revert C3Governor_OutOfBounds();
        // require(_proposal[_nonce].hasFailed[offset] == true, "C3Governor: Do not resend if it did not fail");
        if (!_proposal[_nonce].hasFailed[offset]) revert C3Governor_HasNotFailed();

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
            address _to = target.toAddress();
            (bool success,) = _to.call(remoteData);
            if (success) {
                _proposal[_nonce].hasFailed[offset] = true;
            }
        } else {
            _proposal[_nonce].hasFailed[offset] = true;
            emit C3GovernorLog(_nonce, chainId, target, remoteData);
        }
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
