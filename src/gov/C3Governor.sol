// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3CallerUtils, C3ErrorParam } from "../utils/C3CallerUtils.sol";
import { C3GovernDApp } from "./C3GovernDApp.sol";
import { IC3Governor } from "./IC3Governor.sol";

/**
 * @title C3Governor
 * @dev Governance contract for cross-chain proposal management in the C3 protocol.
 * This contract extends C3GovernDApp to provide proposal-based governance
 * functionality for cross-chain operations.
 * 
 * Key features:
 * - Proposal creation and management
 * - Cross-chain proposal execution
 * - Proposal data storage and retrieval
 * - Failed proposal handling and retry mechanisms
 * 
 * @notice This contract enables governance-driven cross-chain operations
 * @author @potti and @selqui ContinuumDAO
 */
contract C3Governor is IC3Governor, C3GovernDApp {
    using Strings for *;
    using C3CallerUtils for string;

    /// @notice Mapping of proposal nonce to proposal data
    mapping(bytes32 => Proposal) private _proposal;
    
    /// @notice Current proposal identifier
    bytes32 public proposalId;

    /**
     * @dev Constructor for C3Governor
     * @param _gov The governance address
     * @param _c3CallerProxy The C3Caller proxy address
     * @param _txSender The transaction sender address
     * @param _dappID The DApp identifier
     */
    constructor(address _gov, address _c3CallerProxy, address _txSender, uint256 _dappID)
        C3GovernDApp(_gov, _c3CallerProxy, _txSender, _dappID)
    { }

    /**
     * @dev Get the current chain ID
     * @return The current chain ID
     */
    function chainID() internal view returns (uint256) {
        return block.chainid;
    }

    /**
     * @notice Send a single parameter for governance proposal
     * @dev Only the governor can call this function
     * @param _data The proposal data
     * @param _nonce The proposal nonce
     * @notice Reverts if the data is empty
     */
    function sendParams(bytes memory _data, bytes32 _nonce) external onlyGov {
        if (_data.length == 0) {
            revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
        }

        _proposal[_nonce].data.push(_data);
        _proposal[_nonce].hasFailed.push(false);

        // Set the current proposal ID for fallback handling
        proposalId = _nonce;

        emit NewProposal(_nonce);

        _c3gov(_nonce, 0);
    }

    /**
     * @notice Send multiple parameters for governance proposal
     * @dev Only the governor can call this function
     * @param _data Array of proposal data
     * @param _nonce The proposal nonce
     * @notice Reverts if the data array is empty or contains empty data
     */
    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external onlyGov {
        if (_data.length == 0) {
            revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
        }

        for (uint256 i = 0; i < _data.length; i++) {
            if (_data[i].length == 0) {
                revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
            }
            _proposal[_nonce].data.push(_data[i]);
            _proposal[_nonce].hasFailed.push(false);
        }

        // Set the current proposal ID for fallback handling
        proposalId = _nonce;

        emit NewProposal(_nonce);

        for (uint256 i = 0; i < _data.length; i++) {
            _c3gov(_nonce, i);
        }
    }

    /**
     * @notice Execute a governance proposal that has failed
     * @param _nonce The proposal nonce
     * @param _offset The offset within the proposal data
     * @notice Reverts if the offset is out of bounds or the proposal hasn't failed
     */
    function doGov(bytes32 _nonce, uint256 _offset) external {
        if (_offset >= _proposal[_nonce].data.length) {
            revert C3Governor_OutOfBounds();
        }
        if (!_proposal[_nonce].hasFailed[_offset]) {
            revert C3Governor_HasNotFailed();
        }
        _c3gov(_nonce, _offset);
    }

    /**
     * @notice Get proposal data and failure status
     * @param _nonce The proposal nonce
     * @param _offset The offset within the proposal data
     * @return The proposal data
     * @return The failure status
     */
    function getProposalData(bytes32 _nonce, uint256 _offset) external view returns (bytes memory, bool) {
        return (_proposal[_nonce].data[_offset], _proposal[_nonce].hasFailed[_offset]);
    }

    /**
     * @dev Internal function to execute governance proposals
     * @param _nonce The proposal nonce
     * @param _offset The offset within the proposal data
     */
    function _c3gov(bytes32 _nonce, uint256 _offset) internal {
        uint256 _chainId;
        string memory _target;
        bytes memory _remoteData;

        bytes memory _rawData = _proposal[_nonce].data[_offset];
        // TODO add flag which config using gov to send or operator
        (_chainId, _target, _remoteData) = abi.decode(_rawData, (uint256, string, bytes));

        if (_chainId == chainID()) {
            address _to = _target.toAddress();
            (bool _success,) = _to.call(_remoteData);
            if (!_success) {
                _proposal[_nonce].hasFailed[_offset] = true;
            }
        } else {
            _proposal[_nonce].hasFailed[_offset] = true;
            emit C3GovernorLog(_nonce, _chainId, _target, _remoteData);
        }
    }

    /**
     * @notice Get the contract version
     * @return The version number
     */
    function version() public pure returns (uint256) {
        return (1);
    }

    /**
     * @dev Internal function to handle fallback calls
     * @param _selector The function selector
     * @param _data The call data
     * @param _reason The failure reason
     * @return True if the fallback was handled successfully
     */
    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        override
        returns (bool)
    {
        uint256 _len = proposalLength();

        _proposal[proposalId].hasFailed[_len - 1] = true;

        emit LogFallback(_selector, _data, _reason);
        return true;
    }

    /**
     * @notice Get the number of cross-chain invocations in the current proposal
     * @return length The number of cross-chain invocations
     */
    function proposalLength() public view returns (uint256) {
        uint256 _len = _proposal[proposalId].data.length;
        return (_len);
    }
}
