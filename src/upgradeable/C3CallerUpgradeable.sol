// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {IC3Caller} from "../IC3Caller.sol";
import {IC3CallerDApp} from "../dapp/IC3CallerDApp.sol";

import {IC3UUIDKeeper} from "../uuid/IC3UUIDKeeper.sol";
import {C3GovClientUpgradeable} from "./gov/C3GovClientUpgradeable.sol";

import {C3CallerUtils, C3ErrorParam} from "../utils/C3CallerUtils.sol";

/**
 * @title IC3CallerUpgradeable
 * @dev Interface for the upgradeable C3Caller contract
 */
interface IC3CallerUpgradeable is IC3Caller {
    /**
     * @notice Initialize the upgradeable C3Caller contract
     * @param _uuidKeeper Address of the UUID keeper contract
     */
    function initialize(address _uuidKeeper) external;
}

/**
 * @title C3CallerUpgradeable
 * @dev Upgradeable version of the main C3Caller contract for handling cross-chain calls.
 * This contract provides the same functionality as C3Caller but with upgradeable capabilities
 * using the UUPS (Universal Upgradeable Proxy Standard) pattern.
 * 
 * Key features:
 * - Cross-chain call initiation (c3call)
 * - Cross-chain broadcast functionality (c3broadcast)
 * - Cross-chain message execution (execute)
 * - Fallback mechanism for failed calls (c3Fallback)
 * - Pausable functionality for emergency stops
 * - Governance integration for access control
 * - Upgradeable functionality via UUPS pattern
 * 
 * @notice This contract is the upgradeable version of the primary entry point for cross-chain operations
 * @author @potti ContinuumDAO
 */
contract C3CallerUpgradeable is
    IC3CallerUpgradeable,
    C3GovClientUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using Address for address;
    using Address for address payable;
    using C3CallerUtils for bytes;

    /// @notice Current execution context for cross-chain operations
    C3Context public context;
    
    /// @notice Address of the UUID keeper contract for managing unique identifiers
    address public uuidKeeper;

    /**
     * @notice Initialize the upgradeable C3Caller contract
     * @dev This function can only be called once during deployment
     * @param _uuidKeeper Address of the UUID keeper contract
     */
    function initialize(address _uuidKeeper) public initializer {
        __UUPSUpgradeable_init();
        __C3GovClient_init(msg.sender);
        __Ownable_init(msg.sender);
        __Pausable_init();
        uuidKeeper = _uuidKeeper;
    }

    /**
     * @notice Check if an address is an authorized executor
     * @param _sender Address to check
     * @return True if the address is an operator, false otherwise
     */
    function isExecutor(address _sender) external view returns (bool) {
        return isOperator(_sender);
    }

    /**
     * @notice Get the address of this C3Caller contract
     * @return The address of this contract
     */
    function c3caller() public view returns (address) {
        return address(this);
    }

    /**
     * @notice Check if an address is the C3Caller contract itself
     * @param _sender Address to check
     * @return True if the address is this contract, false otherwise
     */
    function isCaller(address _sender) external view returns (bool) {
        // return sender == c3caller;
        return _sender == address(this);
    }

    /**
     * @dev Internal function to initiate a cross-chain call
     * @param _dappID The DApp identifier
     * @param _caller The address initiating the call
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata to execute on the destination chain
     * @param _extra Additional data for the cross-chain call
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
            _to,
            _toChainID,
            _data
        );
        emit LogC3Call(_dappID, _uuid, _caller, _toChainID, _to, _data, _extra);
    }

    /**
     * @notice Initiate a cross-chain call with extra data
     * @dev Called by DApps to initiate cross-chain transactions
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata to execute on the destination chain
     * @param _extra Additional data for the cross-chain call
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
     * @notice Initiate a cross-chain call without extra data
     * @dev Called by DApps to initiate cross-chain transactions
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata to execute on the destination chain
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
     * @dev Internal function to initiate cross-chain broadcasts
     * @param _dappID The DApp identifier
     * @param _caller The address initiating the broadcast
     * @param _to Array of target addresses on destination chains
     * @param _toChainIDs Array of destination chain identifiers
     * @param _data The calldata to execute on destination chains
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
     * @notice Initiate cross-chain broadcasts to multiple destinations
     * @dev Called by DApps to broadcast transactions to multiple chains
     * @param _dappID The DApp identifier
     * @param _to Array of target addresses on destination chains
     * @param _toChainIDs Array of destination chain identifiers
     * @param _data The calldata to execute on destination chains
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
     * @param _dappID The DApp identifier
     * @param _txSender The transaction sender address
     * @param _message The cross-chain message to execute
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
        // check dappID
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

        // BUG: #9 _toUint Cannot Decode ABI-Encoded Dynamic Return Data
        // PASSED:
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
     * @notice Execute a cross-chain message
     * @dev Called by MPC network to execute cross-chain messages
     * @param _dappID The DApp identifier
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
     * @param _dappID The DApp identifier
     * @param _txSender The transaction sender address
     * @param _message The cross-chain message for fallback
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
     * @notice Execute a fallback call for failed cross-chain operations
     * @dev Called by MPC network to handle failed cross-chain calls
     * @param _dappID The DApp identifier
     * @param _message The cross-chain message for fallback
     */
    function c3Fallback(
        uint256 _dappID,
        C3EvmMessage calldata _message
    ) external onlyOperator whenNotPaused {
        _c3Fallback(_dappID, msg.sender, _message);
    }

    /**
     * @dev Internal function to authorize upgrades
     * @param newImplementation The new implementation address
     * @notice Only operators can authorize upgrades
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOperator {}
}
