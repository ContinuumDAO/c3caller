// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {C3CallerUtils, C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {C3GovernDApp} from "./C3GovernDApp.sol";
import {IC3GovernorV2} from "./IC3GovernorV2.sol";

contract C3GovernorV2 is IC3GovernorV2, C3GovernDApp, ReentrancyGuard {
    // using Strings for *;
    using C3CallerUtils for string;

    mapping(uint256 => bool) public proposalRegistered; // INFO: check nonce
    mapping(string => string) public peer; // INFO: address of c3governor on destination chain
    mapping(uint256 => mapping(uint256 => Proposal)) public proposal; // INFO: flag for retries

    uint256 public constant version = 2;

    constructor(address _gov, address _c3CallerProxy, address _txSender, uint256 _dappID)
        C3GovernDApp(_gov, _c3CallerProxy, _txSender, _dappID)
    {}

    // INFO: encoded in a proposal call by Governor on the source chain
    function sendParams(
        uint256 _nonce,
        string[] memory _targetStrs,
        string[] memory _toChainIdStrs,
        bytes[] memory _calldatas
    ) external onlyGov {
        // INFO: check that proposal has not already been initiated
        if (proposalRegistered[_nonce]) {
            revert C3Governor_ExistingProposal(_nonce);
        }

        uint256 refLength = _targetStrs.length; // INFO: gas savings
        if (refLength == 0) {
            revert C3Governor_InvalidLength(C3ErrorParam.To);
        }

        // INFO: check that lengths of each array match
        if (refLength != _toChainIdStrs.length) {
            revert C3Governor_LengthMismatch(C3ErrorParam.To, C3ErrorParam.ChainID);
        } else if (refLength != _calldatas.length) {
            revert C3Governor_LengthMismatch(C3ErrorParam.To, C3ErrorParam.Calldata);
        }

        // INFO: check that no parameters are zero-length
        for (uint8 i = 0; i < refLength; i++) {
            if (bytes(_targetStrs[i]).length == 0) {
                revert C3Governor_InvalidLength(C3ErrorParam.To);
            } else if (bytes(_toChainIdStrs[i]).length == 0) {
                revert C3Governor_InvalidLength(C3ErrorParam.ChainID);
            } else if (bytes(_calldatas[i]).length == 0) {
                revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
            }
        }

        proposalRegistered[_nonce] = true;

        // TODO: add to registry to faciliate retries in event of failure
        // TODO: events?

        // INFO: build calldata for the peer C3Governor on another chain
        for (uint256 i = 0; i < refLength; i++) {
            bytes memory peerEncodedData = abi.encodeWithSignature(
                "receiveParams(uint256,uint256,string,string,bytes)",
                _nonce,
                uint256(i),
                _toChainIdStrs[i],
                _targetStrs[i],
                _calldatas[i]
            );
            _c3call(peer[_toChainIdStrs[i]], _toChainIdStrs[i], peerEncodedData, "");
            _sendParams(_nonce, uint256(i), _targetStrs[i], _toChainIdStrs[i], _calldatas[i]);
        }
    }

    function _sendParams(
        uint256 _nonce,
        uint256 _index,
        string memory _target,
        string memory _toChainIdStr,
        bytes memory _calldata
    ) internal {
        bytes memory peerEncodedData = abi.encodeWithSignature(
            "receiveParams(uint256,uint256,string,bytes)", _nonce, _index, _target, _calldata
        );
        _c3call(peer[_toChainIdStr], _toChainIdStr, peerEncodedData, "");
    }

    // INFO: called by C3Caller.execute on destination chain
    // NOTE: nonce/index/chainID are included to enable fallback reference on failure
    function receiveParams(
        uint256 /*_nonce*/,
        uint256 /*_index*/,
        string memory _targetStr,
        string memory /*_toChainIdStr*/,
        bytes memory _calldata
    ) external onlyCaller returns (bytes memory) {
        address _target = _targetStr.toAddress();
        // INFO: execute the proposal calldata on target
        (bool success, bytes memory result) = _target.call(_calldata);
        if (!success) {
            // INFO: this will inform C3Caller.execute that the execution has failed, triggering _c3Fallback
            revert C3Governor_ExecFailed(result);
        } else {
            return result;
        }
    }

    // INFO: allow retry of sending a given index of a proposal, provided that it failed on previous attempt
    function retrySendParam(uint256 _nonce, uint256 _index) external {
        if (proposal[_nonce][_index].data.length != 0) {
            revert C3Governor_HasNotFailed();
        }
        Proposal memory _proposal = proposal[_nonce][_index];
        _sendParams(_nonce, _index, _proposal.targetStr, _proposal.toChainIdStr, _proposal.data);
        delete proposal[_nonce][_index];
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata /*_reason*/)
        internal
        override
        returns (bool)
    {
        if (_selector == this.receiveParams.selector) {
            // NOTE: _selector == this.receiveParams.selector
            // _data == (nonce, i, chainID, target, calldata)
            (
                uint256 _nonce,
                uint256 _index,
                string memory _toChainIdStr,
                string memory _targetStr,
                bytes memory _calldata
            ) = abi.decode(_data, (uint256, uint256, string, string, bytes));
            proposal[_nonce][_index] = Proposal(_targetStr, _toChainIdStr, _calldata);
        }
        return true;
    }
}
