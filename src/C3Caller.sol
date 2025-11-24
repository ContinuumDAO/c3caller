// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IC3Caller} from "./IC3Caller.sol";
import {IC3CallerDApp} from "./dapp/IC3CallerDApp.sol";
import {IC3DAppManager} from "./dapp/IC3DAppManager.sol";

import {C3GovClient} from "./gov/C3GovClient.sol";
import {IC3UUIDKeeper} from "./uuid/IC3UUIDKeeper.sol";

import {C3ErrorParam} from "./utils/C3CallerUtils.sol";

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
contract C3Caller is IC3Caller, C3GovClient {
    using Address for address;

    /// @notice Current execution context for cross-chain operations, set/reset during each execution
    C3Context public context;

    /// @notice Address of the UUID keeper contract for managing unique identifiers
    address public uuidKeeper;

    /// @notice Address of the DApp manager for managing DApp IDs and their fees
    address public dappManager;

    /// @notice Chain ID string (a destination chain in a c3call) is both deployed to and not paused
    mapping(string => bool) public isActiveChainID;

    /// @notice Array of chain ID strings that are both active and not paused
    string[] public activeChainIDs;

    /// @notice Mapping of addresses to MPC status
    mapping(address => bool) public isMPCAddr;

    /// @notice Array of all operator addresses
    address[] public mpcAddrs;

    /**
     * @notice Modifier to restrict access to MPC addresses
     * @dev Reverts if the caller is not an MPC address
     */
    modifier onlyMPC() {
        if (!isMPCAddr[msg.sender]) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.MPC);
        }
        _;
    }

    /**
     * @param _uuidKeeper Address of the UUID keeper contract
     * @dev Initializes the Owner of the contract to the msg.sender
     */
    constructor(address _uuidKeeper, address _dappManager) C3GovClient(msg.sender) {
        uuidKeeper = _uuidKeeper;
        dappManager = _dappManager;
    }

    /**
     * @notice Initiate a cross-chain call with extra custom data
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _to The target address on the destination network (C3CallerDApp implementation)
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on the destination network (ABI encoded)
     * @param _extra Additional custom data for the cross-chain call
     * @dev Calls `_c3call` with msg.sender as the caller
     */
    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external whenNotPaused returns (bytes32) {
        return _c3call(_dappID, msg.sender, _to, _toChainID, _data, _extra);
    }

    /**
     * @notice Initiate a cross-chain call without extra custom data
     * @dev Called within registered DApps to initiate cross-chain transactions
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _to The target address on the destination network (C3CallerDApp implementation)
     * @param _toChainID The destination network' chain ID
     * @param _data The calldata to execute on the destination network (ABI encoded)
     * @dev Calls `_c3call` with msg.sender as the caller
     */
    function c3call(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)
        external
        whenNotPaused
        returns(bytes32)
    {
        return _c3call(_dappID, msg.sender, _to, _toChainID, _data, "");
    }

    /**
     * @notice Initiate cross-chain broadcasts to multiple chains
     * @dev Called within registered DApps to broadcast transactions to multiple other chains
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _to Array of target addresses on destination networks (C3CallerDApp destination implementations)
     * @param _toChainIDs Array of destination chain IDs
     * @param _data The calldata to execute on each destination network (ABI encoded)
     * @dev Calls `_c3call` with msg.sender as the caller (C3CallerDApp source implementation)
     */
    function c3broadcast(uint256 _dappID, string[] calldata _to, string[] calldata _toChainIDs, bytes calldata _data)
        external
        whenNotPaused
        returns (bytes32[] memory)
    {
        if (_to.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.To);
        }
        if (_toChainIDs.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.ChainID);
        }
        if (_to.length != _toChainIDs.length) {
            revert C3Caller_LengthMismatch(C3ErrorParam.To, C3ErrorParam.ChainID);
        }

        bytes32[] memory uuids = new bytes32[](_toChainIDs.length);

        for (uint256 i = 0; i < _toChainIDs.length; i++) {
            uuids[i] = _c3call(_dappID, msg.sender, _to[i], _toChainIDs[i], _data, "");
        }

        return uuids;
    }

    /**
     * @notice Execute a cross-chain message (this is called on the destination chain)
     * @dev Called by MPC network to execute cross-chain messages
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _message The cross-chain message to execute
     */
    function execute(uint256 _dappID, C3EvmMessage calldata _message) external onlyMPC whenNotPaused {
        _execute(_dappID, msg.sender, _message);
    }

    /**
     * @notice Execute a fallback call for reverted cross-chain operations
     * @param _dappID The ID of the C3CallerDApp implementation
     * @param _message The cross-chain calldata that failed to execute
     * @dev Called by the MPC network on the source network
     */
    function c3Fallback(uint256 _dappID, C3EvmMessage calldata _message) external onlyMPC whenNotPaused {
        _c3Fallback(_dappID, msg.sender, _message);
    }

    /**
     * @notice Mark a chain ID active, allowing c3calls to that chain
     * @param _chainID The chain ID to ensure is active
     * @dev Revert if chain ID is already active
     */
    function activateChainID(string memory _chainID) external onlyGov {
        if (isActiveChainID[_chainID]) {
            revert C3Caller_AlreadyChainID(_chainID);
        }
        isActiveChainID[_chainID] = true;
        activeChainIDs.push(_chainID);
        emit AddChainID(_chainID);
    }

    /**
     * @notice Mark a chain ID inactive, thus preventing c3calls to that chain
     * @param _chainID The chain ID to ensure is inactive
     * @dev This is to prevent payload fees being charged unnecessarily for inactive chains
     * @dev Revert if chain ID is not active
     */
    function deactivateChainID(string memory _chainID) external onlyGov {
        if (!isActiveChainID[_chainID]) {
            revert C3Caller_IsNotChainID(_chainID);
        }
        uint256 chainIDCount = activeChainIDs.length;
        for (uint256 i = 0; i < chainIDCount; i++) {
            if (keccak256(bytes(activeChainIDs[i])) == keccak256(bytes(_chainID))) {
                if (i != chainIDCount - 1) {
                    activeChainIDs[i] = activeChainIDs[chainIDCount - 1];
                }
                activeChainIDs.pop();
                break;
            }
        }
        isActiveChainID[_chainID] = false;
        emit RevokeChainID(_chainID);
    }

    /**
     * @notice Add an MPC
     * @param _mpc The address to add as an MPC
     * @dev Only the governance address can call this function
     */
    function addMPC(address _mpc) external onlyGov {
        if (_mpc == address(0)) {
            revert C3Caller_IsZeroAddress(C3ErrorParam.MPC);
        }
        if (isMPCAddr[_mpc]) {
            revert C3Caller_AlreadyMPC(_mpc);
        }
        isMPCAddr[_mpc] = true;
        mpcAddrs.push(_mpc);
        emit AddMPC(_mpc);
    }

    /**
     * @notice Revoke MPC status from an address
     * @param _mpc The address from which to revoke MPC status
     * @dev Reverts if the address is already not an MPC
     * @dev Only the governance address can call this function
     */
    function revokeMPC(address _mpc) external onlyGov {
        if (!isMPCAddr[_mpc]) {
            revert C3Caller_IsNotMPC(_mpc);
        }
        isMPCAddr[_mpc] = false;
        uint256 _length = mpcAddrs.length;
        for (uint256 _i = 0; _i < _length; _i++) {
            if (mpcAddrs[_i] == _mpc) {
                mpcAddrs[_i] = mpcAddrs[_length - 1];
                mpcAddrs.pop();
                break;
            }
        }
        emit RevokeMPC(_mpc);
    }

    /**
     * @notice Get all active chain IDs
     * @return Array of all chain ID strings
     */
    function getAllActiveChainIDs() external view returns (string[] memory) {
        return activeChainIDs;
    }

    /**
     * @notice Get all MPC addresses
     * @return Array of all MPC addresses
     */
    function getAllMPCAddrs() external view returns (address[] memory) {
        return mpcAddrs;
    }

    /**
     * @dev Internal function to initiate a cross-chain call
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _caller The address initiating the call (C3CallerDApp implementation)
     * @param _to The target address on the destination network (C3CallerDApp implementation)
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on the destination network (ABI encoded)
     * @param _extra Additional custom data for the cross-chain call
     */
    function _c3call(
        uint256 _dappID,
        address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) internal returns (bytes32) {
        if (IC3DAppManager(dappManager).dappAddrID(msg.sender) != _dappID) {
            revert C3Caller_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.DAppID);
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
        if (!isActiveChainID[_toChainID]) {
            revert C3Caller_InactiveChainID(_toChainID);
        }
        IC3DAppManager(dappManager).chargePayload(_dappID, bytes(_data).length);
        bytes32 _uuid = IC3UUIDKeeper(uuidKeeper).genUUID(_dappID, _to, _toChainID, _data);
        emit LogC3Call(_dappID, _uuid, _caller, _toChainID, _to, _data, _extra);

        return _uuid;
    }

    /**
     * @dev Internal function to execute cross-chain messages on the destination network
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _txSender The transaction sender address (should be the MPC network)
     * @param _message The cross-chain message to execute
     * @dev If the call fails, emits a `LogFallbackCall` event which routes to _c3Fallback on the source chain
     */
    function _execute(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal {
        if (_message.data.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.Calldata);
        }
        if (!IC3DAppManager(dappManager).isValidMPCAddr(_dappID, _txSender)) {
            revert C3Caller_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.MPC);
        }

        uint256 expectedDAppID = IC3CallerDApp(_message.to).dappID();
        if (expectedDAppID != _dappID) {
            revert C3Caller_InvalidDAppID(expectedDAppID, _dappID);
        }

        if (IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid)) {
            revert C3Caller_UUIDAlreadyCompleted(_message.uuid);
        }

        context = C3Context({swapID: _message.uuid, fromChainID: _message.fromChainID, sourceTx: _message.sourceTx});

        uint256 gasStart = gasleft();
        (bool success, bytes memory result) = _message.to.call(_message.data);
        uint256 gasEnd = gasleft();

        context = C3Context({swapID: "", fromChainID: "", sourceTx: ""});

        uint256 gasUsed = gasStart - gasEnd;
        uint256 gasFee = gasUsed * tx.gasprice;
        IC3DAppManager(dappManager).chargeGas(_dappID, gasFee);

        emit LogExecCall(
            _dappID, _message.to, _message.uuid, _message.fromChainID, _message.sourceTx, _message.data, success, result
        );

        if (success) {
            IC3UUIDKeeper(uuidKeeper).registerUUID(_message.uuid, _dappID);
        } else {
            emit LogFallbackCall(
                _dappID,
                _message.uuid,
                _message.fallbackTo,
                abi.encodeWithSelector(IC3CallerDApp.c3Fallback.selector, _dappID, _message.data, result),
                result
            );
        }
    }

    /**
     * @dev Internal function to handle fallback calls
     * @param _dappID The DApp identifier of the C3CallerDApp implementation
     * @param _txSender The transaction sender address
     * @param _message The cross-chain calldata that reverted during `execute`
     */
    function _c3Fallback(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal {
        if (_message.data.length == 0) {
            revert C3Caller_InvalidLength(C3ErrorParam.Calldata);
        }
        if (!IC3DAppManager(dappManager).isValidMPCAddr(_dappID, _txSender)) {
            revert C3Caller_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.MPC);
        }
        if (IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid)) {
            revert C3Caller_UUIDAlreadyCompleted(_message.uuid);
        }

        uint256 expectedDAppID = IC3CallerDApp(_message.to).dappID();
        if (expectedDAppID != _dappID) {
            revert C3Caller_InvalidDAppID(expectedDAppID, _dappID);
        }

        address _target = _message.to;

        context = C3Context({swapID: _message.uuid, fromChainID: _message.fromChainID, sourceTx: _message.sourceTx});

        uint256 gasStart = gasleft();
        bytes memory _result = _target.functionCall(_message.data);
        uint256 gasEnd = gasleft();

        context = C3Context({swapID: "", fromChainID: "", sourceTx: ""});

        // NOTE: charging for fallback in case malicious DApp makes their c3Fallback function hugely expensive
        uint256 gasUsed = gasStart - gasEnd;
        uint256 gasFee = gasUsed * tx.gasprice;
        IC3DAppManager(dappManager).chargeGas(_dappID, gasFee);

        IC3UUIDKeeper(uuidKeeper).registerUUID(_message.uuid, _dappID);

        emit LogExecFallback(
            _dappID, _message.to, _message.uuid, _message.fromChainID, _message.sourceTx, _message.data, _result
        );
    }
}
