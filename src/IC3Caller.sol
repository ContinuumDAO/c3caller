// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

library C3CallerStructLib {
    struct C3EvmMessage {
        bytes32 uuid;
        address to;
        string fromChainID;
        string sourceTx;
        string fallbackTo;
        bytes data;
    }
}

// interface IC3CallerProxy {
//     function isExecutor(address sender) external returns (bool);
// 
//     function isCaller(address sender) external returns (bool);
// 
//     function context()
//         external
//         view
//         returns (
//             bytes32 swapID,
//             string memory fromChainID,
//             string memory sourceTx
//         );
// 
//     function c3call(
//         uint256 _dappID,
//         string calldata _to,
//         string calldata _toChainID,
//         bytes calldata _data
//     ) external;
// 
//     function c3call(
//         uint256 _dappID,
//         string calldata _to,
//         string calldata _toChainID,
//         bytes calldata _data,
//         bytes memory _extra
//     ) external;
// 
//     function c3broadcast(
//         uint256 _dappID,
//         string[] calldata _to,
//         string[] calldata _toChainIDs,
//         bytes calldata _data
//     ) external;
// 
//     function execute(
//         uint256 _dappID,
//         C3CallerStructLib.C3EvmMessage calldata _message
//     ) external;
// 
//     function c3Fallback(
//         uint256 dappID,
//         C3CallerStructLib.C3EvmMessage calldata _message
//     ) external;
// }

interface IC3Dapp {
    function c3Fallback(
        uint256 dappID,
        bytes calldata data,
        bytes calldata reason
    ) external returns (bool);

    function dappID() external returns (uint256);

    function isVaildSender(address txSender) external returns (bool);
}

interface IC3Caller {
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
