// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

interface IC3GovernorV2 {
    // event NewProposal(uint256 indexed uuid);

    // event C3GovernorLog(uint256 indexed _nonce, uint256 indexed _toChainID, string _to, bytes _toData);

    // event LogChangeMPC(
    //     address indexed _oldMPC, address indexed _newMPC, uint256 indexed _effectiveTime, uint256 _chainID
    // );

    // event LogFallback(bytes4 _selector, bytes _data, bytes _reason);
    // event LogChangeGov(address _gov, address _newGov);
    // event LogSendParams(address _target, uint256 _chainId, bytes _dataXChain);

    error C3Governor_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3Governor_ExistingProposal(uint256);
    error C3Governor_LengthMismatch(C3ErrorParam, C3ErrorParam);
    error C3Governor_InvalidLength(C3ErrorParam);
    error C3Governor_ExecFailed(bytes);
    // error C3Governor_OutOfBounds();
    error C3Governor_HasNotFailed();

    struct Proposal {
        string targetStr;
        string toChainIdStr;
        bytes data;
    }

    function proposalRegistered(uint256 _nonce) external view returns (bool);
    function peer(string memory _chainIdStr) external view returns (string memory);
    function proposal(uint256 _nonce, uint256 _index) external view returns (string memory,string memory,bytes memory);

    function sendParams(
        uint256 _nonce,
        string[] memory _targetStrs,
        string[] memory _toChainIdStrs,
        bytes[] memory _calldatas
    ) external;
    function receiveParams(
        uint256 _nonce,
        uint256 _index,
        string memory _targetStr,
        string memory _toChainIdStr,
        bytes memory _calldata
    ) external returns (bytes memory);
    function retrySendParam(uint256 _nonce, uint256 _index) external;
    function version() external pure returns (uint256);
}
