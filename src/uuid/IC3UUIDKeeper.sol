// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

interface IC3UUIDKeeper {
    error C3UUIDKeeper_UUIDAlreadyExists(bytes32);
    error C3UUIDKeeper_UUIDAlreadyCompleted(bytes32);

    function registerUUID(bytes32 _uuid) external;

    function genUUID(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)
        external
        returns (bytes32 _uuid);

    function isCompleted(bytes32 _uuid) external view returns (bool);
    function isUUIDExist(bytes32 _uuid) external view returns (bool);
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
