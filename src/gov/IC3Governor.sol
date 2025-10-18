// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

interface IC3Governor {
    event C3GovernorCall(
        uint256 indexed _nonce, uint256 _index, string _targetStr, string _toChainIdStr, bytes _calldata
    );
    event C3GovernorFallback(
        uint256 indexed _nonce, uint256 _index, string _targetStr, string _toChainIdStr, bytes _calldata, bytes _reason
    );
    event C3GovernorExec(
        uint256 indexed _nonce, uint256 _index, string _targetStr, string _toChainIdStr, bytes _calldata
    );

    error C3Governor_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3Governor_InvalidProposal(uint256);
    error C3Governor_LengthMismatch(C3ErrorParam, C3ErrorParam);
    error C3Governor_InvalidLength(C3ErrorParam);
    error C3Governor_ExecFailed(bytes);
    error C3Governor_HasNotFailed();
    error C3Governor_UnsupportedChainID(string);

    struct Proposal {
        string target;
        string toChainId;
        bytes data;
    }

    function proposalRegistered(uint256 _nonce) external view returns (bool);
    function peer(string memory _chainIdStr) external view returns (string memory);
    function failed(uint256 _nonce, uint256 _index) external view returns (string memory, string memory, bytes memory);

    function setPeer(string memory _chainIdStr, string memory _peerStr) external;
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
    function doGov(uint256 _nonce, uint256 _index) external;
    function VERSION() external pure returns (uint256);
}
