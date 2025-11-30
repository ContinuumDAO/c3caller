// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3Governor} from "./IC3Governor.sol";
import {IC3GovClient} from "./IC3GovClient.sol";
import {C3GovernDApp} from "./C3GovernDApp.sol";
import {C3CallerUtils, C3ErrorParam} from "../utils/C3CallerUtils.sol";

/**
 * @title C3Governor
 * @notice Contract that acts as a proxy to enable governance protocols to execute their decisions to other networks.
 * A client is deployed on every applicable network and clients communicate with one another to send/receive data.
 * The most typical use case is with OpenZeppelin's Governor. A successful proposal can have as one of its actions a
 * call to this contract's function `sendParams` with an array of target contracts, their chain IDs, and calldata.
 * Included as a feature is the ability to retry reverted transactions, mirroring the execute function in Governor.
 * If one or more actions from a proposal fail, anyone may retry them until they succeed, obviating the need for
 * a duplicate proposal.
 *
 * @author @patrickcure @potti @Selqui (ContinuumDAO)
 */
contract C3Governor is IC3Governor, C3GovernDApp {
    using C3CallerUtils for string;

    /// @notice A registry of active proposal IDs (or a custom nonce).
    mapping(uint256 => bool) public proposalRegistered;

    /// @notice Actions that have failed on the destination network have their data stored until they are retried.
    mapping(uint256 => mapping(uint256 => Proposal)) public failed;

    /// @notice The C3Governor clients deployed to destination networks.
    mapping(string => string) public peer;

    /**
     * @param _gov Deployed Governor contract (or admin of choice).
     * @param _c3caller The C3Caller deployed instance.
     * @param _dappID The DApp ID of this C3CallerDApp.
     */
    constructor(address _gov, address _c3caller, uint256 _dappID) C3GovernDApp(_gov, _c3caller, _dappID) {}

    /**
     * @notice Entry point for a proposal to be executed on another network (called by Governor).
     *   This call should be encoded in a Governor proposal. Each proposal may only be initiated once.
     * @param _nonce The ID of the proposal (can only be done once per proposal).
     * @param _targetStrs The array of addresses that will be called on the destination network.
     * @param _toChainIdStrs The array of chain IDs for each transaction.
     * @param _calldatas The array of calldata that will be called on the corresponding address.
     * @dev Arrays must be the same length, non-zero values. Chain IDs must be registered peers.
     */
    function sendParams(
        uint256 _nonce,
        string[] memory _targetStrs,
        string[] memory _toChainIdStrs,
        bytes[] memory _calldatas
    ) external onlyGov {
        if (proposalRegistered[_nonce]) {
            revert C3Governor_InvalidProposal(_nonce);
        }

        proposalRegistered[_nonce] = true;

        uint256 refLength = _targetStrs.length; // INFO: gas savings
        if (refLength == 0) {
            revert C3Governor_InvalidLength(C3ErrorParam.To);
        }

        if (refLength != _toChainIdStrs.length) {
            revert C3Governor_LengthMismatch(C3ErrorParam.To, C3ErrorParam.ChainID);
        } else if (refLength != _calldatas.length) {
            revert C3Governor_LengthMismatch(C3ErrorParam.To, C3ErrorParam.Calldata);
        }

        for (uint8 i = 0; i < refLength; i++) {
            if (bytes(_targetStrs[i]).length == 0) {
                revert C3Governor_InvalidLength(C3ErrorParam.To);
            } else if (bytes(peer[_toChainIdStrs[i]]).length == 0) {
                revert C3Governor_UnsupportedChainID(_toChainIdStrs[i]);
            } else if (bytes(_calldatas[i]).length == 0) {
                revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
            }
        }

        // INFO: build calldata for the peer C3Governor on another chain
        for (uint256 i = 0; i < refLength; i++) {
            _sendParams(_nonce, i, _targetStrs[i], _toChainIdStrs[i], _calldatas[i]);
            emit C3GovernorCall(_nonce, i, _targetStrs[i], _toChainIdStrs[i], _calldatas[i]);
        }
    }

    // INFO: called by C3Caller.execute on destination chain
    // NOTE: nonce/index/chainID are included to enable fallback reference on failure
    /**
     * @notice Entry point on the destination network for calls that were initiated with `sendParams`.
     * @param _nonce The ID of the proposal from the source network.
     * @param _index The index of the transaction on the proposal.
     * @param _targetStr The address of the contract to call on the destination network.
     * @param _toChainIdStr The chain ID of the destination network (the network this function is called on).
     * @param _calldata The data to call on the corresponding contract address.
     * @dev Called by C3Caller execute. If the transaction reverts, it will be routed to fallback on source chain.
     */
    function receiveParams(
        uint256 _nonce,
        uint256 _index,
        string memory _targetStr,
        string memory _toChainIdStr,
        bytes memory _calldata
    ) external onlyC3Caller returns (bytes memory) {
        address _target = _targetStr.toAddress();
        // INFO: execute the proposal calldata on target
        (bool success, bytes memory result) = _target.call(_calldata);
        if (!success) {
            // INFO: this will inform C3Caller.execute that the execution has failed, triggering _c3Fallback
            revert C3Governor_ExecFailed(result);
        } else {
            emit C3GovernorExec(_nonce, _index, _targetStr, _toChainIdStr, _calldata);
            return result;
        }
    }

    // INFO: allow retry of sending a given index of a given proposal, provided that it failed on previous attempt
    /**
     * @notice Allow anyone to retry a given transaction of a given proposal that reverted on another network.
     * @param _nonce The proposal ID of the transaction.
     * @param _index The index of the transaction in the proposal.
     * @dev Some transactions in a given proposal may fail, but this does not stop other transactions in the proposal
     *   from succeeding. This should be anticipated in the target contract architecture.
     */
    function doGov(uint256 _nonce, uint256 _index) external {
        if (!proposalRegistered[_nonce]) {
            revert C3Governor_InvalidProposal(_nonce);
        }

        // NOTE: failed is only set by fallback
        if (failed[_nonce][_index].data.length == 0) {
            revert C3Governor_HasNotFailed();
        }

        Proposal memory _proposal = failed[_nonce][_index];
        // NOTE: remove data to ensure it is only called once
        delete failed[_nonce][_index];
        _sendParams(_nonce, _index, _proposal.target, _proposal.toChainId, _proposal.data);
    }

    /**
     * @notice Tool for applying C3Governor (this contract) as the governance address where valid on a given
     * implementation of C3GovClient (for example: C3Caller, C3UUIDKeeper, C3DAppManager).
     * @param _target The address of the implementation
     * @dev If the target address C3GovClient:changeGov has not been called with C3Governor (this) as the new governance
     * address, this call will fail, therefore anyone can call this safely
     */
    function applySelfAsGov(address _target) external {
        IC3GovClient(_target).applyGov();
    }

    /**
     * @notice Sets the peer address for a given chain ID.
     * @param _chainIdStr The chain ID to set.
     * @param _peerStr The deployed peer client on that network.
     * @dev Chain ID and peer address are encoded as a string to allow non-EVM data.
     */
    function setPeer(string memory _chainIdStr, string memory _peerStr) external onlyGov {
        peer[_chainIdStr] = _peerStr;
    }

    /**
     * @notice Internal handler called by `sendParams` and `doGov`.
     * @param _nonce The ID of the proposal.
     * @param _index The index of the transaction on the proposal.
     * @param _target The address of the contract to call on the destination network.
     * @param _toChainIdStr The chain ID of the destination network.
     * @param _calldata The data to execute on the corresponding contract address.
     */
    function _sendParams(
        uint256 _nonce,
        uint256 _index,
        string memory _target,
        string memory _toChainIdStr,
        bytes memory _calldata
    ) internal {
        bytes memory peerEncodedData = abi.encodeWithSelector(
            this.receiveParams.selector, _nonce, _index, _target, _toChainIdStr, _calldata
        );
        _c3call(peer[_toChainIdStr], _toChainIdStr, peerEncodedData, "");
    }

    /**
     * @notice Called by C3Caller on the source network in the event of a reverted transaction.
     * @param _selector The 4-byte selector of the transaction (necessarily the selector of `receiveParams`).
     * @param _data The revert data (passed in as the arguments to the failed `receiveParams`).
     * @param _reason The revert data of the failed `receiveParams`(encoded in the custom error C3Governor_ExecFailed).
     * @dev This marks the transaction as eligible to retry using `doGov` by saving its target, chain ID and calldata.
     */
    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        override
        returns (bool)
    {
        if (_selector == this.receiveParams.selector) {
            // NOTE: `receiveParams` always reverts with C3Governor_ExecFailed(bytes reason)
            bytes memory reason = abi.decode(_reason[4:], (bytes));
            // NOTE: _data == (nonce, i, chainID, target, calldata)
            (
                uint256 _nonce,
                uint256 _index,
                string memory _targetStr,
                string memory _toChainIdStr,
                bytes memory _calldata
            ) = abi.decode(_data, (uint256, uint256, string, string, bytes));
            failed[_nonce][_index] = Proposal(_targetStr, _toChainIdStr, _calldata);
            emit C3GovernorFallback(_nonce, _index, _targetStr, _toChainIdStr, _calldata, reason);
            return true;
        } else {
            return false;
        }
    }
}
