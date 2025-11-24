// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3GovClient} from "./gov/IC3GovClient.sol";
import {C3ErrorParam} from "./utils/C3CallerUtils.sol";

interface IC3Caller is IC3GovClient {
    // Layout
    struct C3Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
    }

    struct C3EvmMessage {
        bytes32 uuid;
        address to;
        string fromChainID;
        string sourceTx;
        string fallbackTo;
        bytes data;
    }

    // Events
    event LogC3Call(
        uint256 indexed dappID,
        bytes32 indexed uuid,
        address indexed caller,
        string toChainID,
        string to,
        bytes data,
        bytes extra
    );
    event LogExecCall(
        uint256 indexed dappID,
        address indexed to,
        bytes32 indexed uuid,
        string fromChainID,
        string sourceTx,
        bytes data,
        bool success,
        bytes reason
    );
    event LogExecFallback(
        uint256 indexed dappID,
        address indexed to,
        bytes32 indexed uuid,
        string fromChainID,
        string sourceTx,
        bytes data,
        bytes reason
    );
    event LogFallbackCall(uint256 indexed dappID, bytes32 indexed uuid, string to, bytes data, bytes reasons);
    event AddChainID(string indexed _chainID);
    event RevokeChainID(string indexed _chainID);
    event AddMPC(address indexed _mpc);
    event RevokeMPC(address indexed _mpc);

    // Errors
    error C3Caller_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3Caller_InvalidLength(C3ErrorParam);
    error C3Caller_LengthMismatch(C3ErrorParam, C3ErrorParam);
    error C3Caller_IsZero(C3ErrorParam);
    error C3Caller_InactiveChainID(string _chainID);
    error C3Caller_InvalidDAppID(uint256 _expected, uint256 _actual);
    error C3Caller_UUIDAlreadyCompleted(bytes32 _uuid);
    error C3Caller_IsZeroAddress(C3ErrorParam);
    error C3Caller_AlreadyChainID(string _chainID);
    error C3Caller_IsNotChainID(string _chainID);
    error C3Caller_AlreadyMPC(address _mpc);
    error C3Caller_IsNotMPC(address _mpc);

    // State
    function context() external view returns (bytes32 uuid, string memory fromChainID, string memory sourceTx);
    function uuidKeeper() external view returns (address);
    function dappManager() external view returns (address);
    function isActiveChainID(string memory _chainID) external view returns (bool);
    function activeChainIDs(uint256 _index) external view returns (string memory);
    function isMPCAddr(address _mpc) external view returns (bool);
    function mpcAddrs(uint256 _index) external view returns (address);

    // Mut
    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external returns (bytes32);
    function c3call(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data) external returns (bytes32);
    function c3broadcast(uint256 _dappID, string[] calldata _to, string[] calldata _toChainIDs, bytes calldata _data)
        external returns (bytes32[] memory);
    function execute(uint256 _dappID, C3EvmMessage calldata _message) external;
    function c3Fallback(uint256 _dappID, C3EvmMessage calldata _message) external;
    function activateChainID(string memory _chainID) external;
    function deactivateChainID(string memory _chainID) external;
    function addMPC(address _mpc) external;
    function revokeMPC(address _mpc) external;

    // View
    function getAllActiveChainIDs() external view returns (string[] memory);
    function getAllMPCAddrs() external view returns (address[] memory);

    // Internal Mut
    // function _c3call(uint256 _dappID, address _caller, string calldata _to, string calldata _toChainID, bytes calldata _data, bytes memory _extra) internal;
    // function _execute(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal;
    // function _c3Fallback(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal;
}
