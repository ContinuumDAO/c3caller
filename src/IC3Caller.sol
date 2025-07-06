// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { C3CallerStructLib } from "./C3CallerStructLib.sol";

import { IC3GovClient } from "./gov/IC3GovClient.sol";

interface IC3Caller is IC3GovClient {
    function isExecutor(address sender) external returns (bool);

    function isCaller(address sender) external returns (bool);

    function context() external view returns (bytes32 uuid, string memory fromChainID, string memory sourceTx);

    function c3call(
        uint256 _dappID,
        // address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external;

    function c3call(
        uint256 _dappID,
        // address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external;

    function c3broadcast(
        uint256 _dappID,
        // address _caller,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) external;

    function execute(
        uint256 _dappID,
        // address _txSender,
        C3CallerStructLib.C3EvmMessage calldata message
    ) external;

    function c3Fallback(
        uint256 dappID,
        // address _txSender,
        C3CallerStructLib.C3EvmMessage calldata message
    ) external;
}
