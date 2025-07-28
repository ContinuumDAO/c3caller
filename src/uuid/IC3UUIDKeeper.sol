// SPDX-License-Identifier: BSL-1.1

pragma solidity ^0.8.22;

interface IC3UUIDKeeper {
    function registerUUID(bytes32 uuid) external;

    function genUUID(uint256 dappID, string calldata to, string calldata toChainID, bytes calldata data)
        external
        returns (bytes32 uuid);

    function isCompleted(bytes32 uuid) external view returns (bool);
}
