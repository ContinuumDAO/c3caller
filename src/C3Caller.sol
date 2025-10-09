// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IC3Caller} from "./IC3Caller.sol";
import {IC3CallerDApp} from "./dapp/IC3CallerDApp.sol";

import {C3GovClient} from "./gov/C3GovClient.sol";
import {IC3UUIDKeeper} from "./uuid/IC3UUIDKeeper.sol";

import {C3CallerUtils, C3ErrorParam} from "./utils/C3CallerUtils.sol";

/**
 * @title C3Caller
 * @dev Main contract for handling cross-chain calls in the Continuum Cross-Chain protocol.
 * This contract serves as the central hub for initiating and executing cross-chain transactions.
 * It integrates with governance, UUID management, and DApp functionality.
 * 
 * Key features
 * Source Network:
 * - Cross-chain call initiation (c3call)
 * - Cross-chain multiple calls functionality (c3broadcast)
 * - Fallback mechanism for failed calls (c3Fallback)
 * Destination Network:
 * - Cross-chain message execution (execute)
 *
 * - Pausable functionality for emergency stops
 * - Governance integration for access control
 * 
 * @notice This contract is the primary entry point for cross-chain operations
 * @author @potti ContinuumDAO
 */
contract C3Caller is IC3Caller, C3GovClient, Ownable, Pausable {
    using Address for address;
    using Address for address payable;
    using C3CallerUtils for bytes;

    /// @notice Current execution context for cross-chain operations, set/reset during each execution
    C3Context public context;

    /// @notice Address of the UUID keeper contract for managing unique identifiers
    address public uuidKeeper;

    /**
     * @dev Constructor for C3Caller contract
     * @param _uuidKeeper Address of the UUID keeper contract
     * @notice Initializes the Owner of the contract to the msg.sender
     */
    constructor(
        address _uuidKeeper
    ) C3GovClient(msg.sender) Ownable(msg.sender) Pausable() {
        uuidKeeper = _uuidKeeper;
    }

    /**
     * @notice Check if an address is an authorized executor (aka operator)
     * @param _sender Address to check
     * @return True if the address is an operator, false otherwise
     */
    function isExecutor(address _sender) external view returns (bool) {
        return isOperator[_sender];
    }

    /**
     * @notice Get the address of this C3Caller contract, for backwards compatibility
     * @return The address of this contract
     */
    function c3caller() public view returns (address) {
        return address(this);
    }

    /**
     * @notice Check if an address is the C3Caller contract itself, for backwards compatibility
     * @param _sender Address to check
     * @return True if the address is this contract, false otherwise
     */
    function isCaller(address _sender) external view returns (bool) {
        return _sender == address(this);
    }

    /**
     * @dev Internal function to initiate a cross-chain call
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _caller The address initiating the call
     * @param _to The target address on the destination chain (C3CallerDApp implementation)
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on the destination chain (ABI encoded)
     * @param _extra Additional custom data for the cross-chain call
     */
    function _c3call(
        uint256 _dappID,
        address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) internal {
        if (_dappID == 0) {
            revert C3Caller_IsZero(C3ErrorParam.DAppID);
        }
        if (bytes(_to).length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.To);
        }
        if (bytes(_toChainID).length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.ChainID);
        }
        if (_data.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.Calldata);
        }
        bytes32 _uuid = IC3UUIDKeeper(uuidKeeper).genUUID(
            _dappID,
            _to, _toChainID,
            _data
        );
        emit LogC3Call(_dappID, _uuid, _caller, _toChainID, _to, _data, _extra);
    }

    /**
     * @notice Initiate a cross-chain call with extra custom data
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _to The target address on the destination chain (C3CallerDApp implementation)
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on the destination chain (ABI encoded)
     * @param _extra Additional custom data for the cross-chain call
     * @dev Calls `_c3call` with msg.sender as the caller
     */
    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external whenNotPaused {
        _c3call(_dappID, msg.sender, _to, _toChainID, _data, _extra);
    }

    /**
     * @notice Initiate a cross-chain call without extra custom data
     * @dev Called within registered DApps to initiate cross-chain transactions
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _to The target address on the destination chain (C3CallerDApp implementation)
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on the destination chain (ABI encoded)
     * @dev Calls `_c3call` with msg.sender as the caller
     */
    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external whenNotPaused {
        _c3call(_dappID, msg.sender, _to, _toChainID, _data, "");
    }

    /**
     * @dev Internal function to initiate multiple cross-chain calls
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _caller The address initiating the broadcast
     * @param _to Array of target addresses on destination chains (C3CallerDApp implementation)
     * @param _toChainIDs Array of destination chain IDs
     * @param _data The calldata to execute on each destination chain (ABI encoded)
     */
    function _c3broadcast(
        uint256 _dappID,
        address _caller,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) internal {
        if (_dappID == 0) {
            revert C3Caller_IsZero(C3ErrorParam.DAppID);
        }
        if (_to.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.To);
        }
        if (_toChainIDs.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.ChainID);
        }
        if (_data.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.Calldata);
        }
        if (_to.length != _toChainIDs.length) {
            revert C3Caller_LengthMismatch(
                C3ErrorParam.To,
                C3ErrorParam.ChainID
            );
        }

        for (uint256 i = 0; i < _toChainIDs.length; i++) {
            bytes32 _uuid = IC3UUIDKeeper(uuidKeeper).genUUID(
                _dappID,
                _to[i],
                _toChainIDs[i],
                _data
            );
            emit LogC3Call(
                _dappID,
                _uuid,
                _caller,
                _toChainIDs[i],
                _to[i],
                _data,
                ""
            );
        }
    }

    /**
     * @notice Initiate cross-chain broadcasts to multiple chains
     * @dev Called within registered DApps to broadcast transactions to multiple other chains
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _to Array of target addresses on destination chains (C3CallerDApp implementation)
     * @param _toChainIDs Array of destination chain IDs
     * @param _data The calldata to execute on each destination chain (ABI encoded)
     * @dev Calls `_c3broadcast` with msg.sender as the caller
     */
    function c3broadcast(
        uint256 _dappID,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) external whenNotPaused {
        _c3broadcast(_dappID, msg.sender, _to, _toChainIDs, _data);
    }

    /**
     * @dev Internal function to execute cross-chain messages
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _txSender The transaction sender address (should be the MPC network)
     * @param _message The cross-chain message to execute
     * @dev Calls `_c3Fallback` if the call fails
     */
    function _execute(
        uint256 _dappID,
        address _txSender,
        C3EvmMessage calldata _message
    ) internal {
        if (_message.data.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.Calldata);
        }
        if (!IC3CallerDApp(_message.to).isValidSender(_txSender)) {
            revert C3Caller_OnlyAuthorized(C3ErrorParam.To, C3ErrorParam.Valid);
        }
        uint256 expectedDAppID = IC3CallerDApp(_message.to).dappID();
        if (expectedDAppID != _dappID) {
            revert C3Caller_InvalidDAppID(expectedDAppID, _dappID);
        }

        if (IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid)) {
            revert C3Caller_UUIDAlreadyCompleted(_message.uuid);
        }

        context = C3Context({
            swapID: _message.uuid,
            fromChainID: _message.fromChainID,
            sourceTx: _message.sourceTx
        });

        (bool success, bytes memory result) = _message.to.call(_message.data);

        context = C3Context({swapID: "", fromChainID: "", sourceTx: ""});

        emit LogExecCall(
            _dappID,
            _message.to,
            _message.uuid,
            _message.fromChainID,
            _message.sourceTx,
            _message.data,
            success,
            result
        );

        if (success) {
            IC3UUIDKeeper(uuidKeeper).registerUUID(_message.uuid);
        } else {
            emit LogFallbackCall(
                _dappID,
                _message.uuid,
                _message.fallbackTo,
                abi.encodeWithSelector(
                    IC3CallerDApp.c3Fallback.selector,
                    _dappID,
                    _message.data,
                    result
                ),
                result
            );
        }
    }

    /**
     * @notice Execute a cross-chain message (this is called on the target chain)
     * @dev Called by MPC network to execute cross-chain messages
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _message The cross-chain message to execute
     */
    function execute(
        uint256 _dappID,
        C3EvmMessage calldata _message
    ) external onlyOperator whenNotPaused {
        _execute(_dappID, msg.sender, _message);
    }

    /**
     * @dev Internal function to handle fallback calls
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _txSender The transaction sender address
     * @param _message The cross-chain calldata that failed to execute
     */
    function _c3Fallback(
        uint256 _dappID,
        address _txSender,
        C3EvmMessage calldata _message
    ) internal {
        if (_message.data.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.Calldata);
        }
        if (IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid)) {
            revert C3Caller_UUIDAlreadyCompleted(_message.uuid);
        }
        if (!IC3CallerDApp(_message.to).isValidSender(_txSender)) {
            revert C3Caller_OnlyAuthorized(C3ErrorParam.To, C3ErrorParam.Valid);
        }

        uint256 expectedDAppID = IC3CallerDApp(_message.to).dappID();
        if (expectedDAppID != _dappID) {
            revert C3Caller_InvalidDAppID(expectedDAppID, _dappID);
        }

        context = C3Context({
            swapID: _message.uuid,
            fromChainID: _message.fromChainID,
            sourceTx: _message.sourceTx
        });

        address _target = _message.to;

        bytes memory _result = _target.functionCall(_message.data);

        context = C3Context({swapID: "", fromChainID: "", sourceTx: ""});

        IC3UUIDKeeper(uuidKeeper).registerUUID(_message.uuid);

        emit LogExecFallback(
            _dappID,
            _message.to,
            _message.uuid,
            _message.fromChainID,
            _message.sourceTx,
            _message.data,
            _result
        );
    }

    /**
     * @notice Execute a fallback call for failed cross-chain operations (this is called on the origin chain)
     * @dev Called by MPC network to handle failed cross-chain calls
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _message The cross-chain calldata that failed to execute
     */
    function c3Fallback(
        uint256 _dappID,
        C3EvmMessage calldata _message
    ) external onlyOperator whenNotPaused {
        _c3Fallback(_dappID, msg.sender, _message);
    }
}
