// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

interface IC3UUIDKeeper {
    event UUIDGenerated(
        bytes32 indexed uuid,
        uint256 indexed dappID,
        address indexed operator,
        string to,
        string toChainID,
        uint256 nonce,
        bytes data
    );

    event UUIDCompleted(bytes32 indexed uuid, uint256 indexed dappID, address indexed operator);

    event UUIDRevoked(bytes32 indexed uuid, uint256 indexed dappID, address indexed governor);

    error C3UUIDKeeper_UUIDAlreadyExists(bytes32);
    error C3UUIDKeeper_UUIDAlreadyCompleted(bytes32);

    function completedSwapin(bytes32 _uuid) external view returns (bool);
    function uuid2Nonce(bytes32 _uuid) external view returns (uint256);
    function currentNonce() external view returns (uint256);

    function genUUID(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)
        external
        returns (bytes32 _uuid);

    function registerUUID(bytes32 _uuid, uint256 _dappID) external;

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

    function revokeSwapin(bytes32 _uuid, uint256 _dappID) external;
}
