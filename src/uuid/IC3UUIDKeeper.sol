// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

interface IC3UUIDKeeper {
    // Events
    event UUIDGenerated(
        bytes32 indexed uuid,
        uint256 indexed dappID,
        address indexed operator,
        string to,
        string toChainID,
        uint256 nonce,
        bytes data
    );
    event UUIDRevoked(bytes32 indexed uuid, uint256 indexed dappID, address indexed governor);
    event UUIDCompleted(bytes32 indexed uuid, uint256 indexed dappID, address indexed operator);

    // Errors
    error C3UUIDKeeper_UUIDAlreadyCompleted(bytes32);
    error C3UUIDKeeper_UUIDAlreadyExists(bytes32);

    // State
    function currentNonce() external view returns (uint256);
    function completedSwapin(bytes32 _uuid) external view returns (bool);
    function uuid2Nonce(bytes32 _uuid) external view returns (uint256);

    // Mut
    function genUUID(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)
        external
        returns (bytes32 _uuid);
    function registerUUID(bytes32 _uuid, uint256 _dappID) external;
    function revokeSwapin(bytes32 _uuid, uint256 _dappID) external;

    // View
    function isCompleted(bytes32 _uuid) external view returns (bool);
    function doesUUIDExist(bytes32 _uuid) external view returns (bool);
    function calcCallerUUID(
        address _from,
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external view returns (bytes32);
    function calcCallerUUIDWithNonce(
        address _from,
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        uint256 _nonce
    ) external view returns (bytes32);
    function calcCallerEncode(
        address _from,
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external view returns (bytes memory);
}
