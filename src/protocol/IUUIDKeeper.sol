// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUUIDKeeper {
    function registerUUID(bytes32 uuid) external;

    function genUUID(
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) external returns (bytes32 uuid);

    function isCompleted(bytes32 uuid) external view returns (bool);
}
