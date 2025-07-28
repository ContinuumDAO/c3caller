// SPDX-License-Identifier: BSL-1.1

pragma solidity ^0.8.22;

import { C3CallerStructLib } from "./C3CallerStructLib.sol";

import { IC3GovClient } from "./gov/IC3GovClient.sol";

interface IC3Caller is IC3GovClient {
    event LogC3Call(
        uint256 indexed dappID,
        bytes32 indexed uuid,
        address caller,
        string toChainID,
        string to,
        bytes data,
        bytes extra
    );

    event LogFallbackCall(uint256 indexed dappID, bytes32 indexed uuid, string to, bytes data, bytes reasons);

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

    function isExecutor(address sender) external returns (bool);

    function isCaller(address sender) external returns (bool);

    function context() external view returns (bytes32 uuid, string memory fromChainID, string memory sourceTx);

    function c3call(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data) external;

    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external;

    function c3broadcast(uint256 _dappID, string[] calldata _to, string[] calldata _toChainIDs, bytes calldata _data)
        external;

    function execute(uint256 _dappID, C3CallerStructLib.C3EvmMessage calldata message) external;

    function c3Fallback(uint256 dappID, C3CallerStructLib.C3EvmMessage calldata message) external;
}
