// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";

interface IC3Governor {
    event NewProposal(uint256 indexed uuid);

    event C3GovernorLog(uint256 indexed _nonce, uint256 indexed _toChainID, string _to, bytes _toData);

    event LogChangeMPC(
        address indexed _oldMPC, address indexed _newMPC, uint256 indexed _effectiveTime, uint256 _chainID
    );

    event LogFallback(bytes4 _selector, bytes _data, bytes _reason);
    event LogChangeGov(address _gov, address _newGov);
    event LogSendParams(address _target, uint256 _chainId, bytes _dataXChain);

    error C3Governor_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3Governor_ExistingProposal(uint256);
    error C3Governor_LengthMismatch(C3ErrorParam, C3ErrorParam);
    error C3Governor_InvalidLength(C3ErrorParam);
    error C3Governor_ExecFailed(bytes);
    error C3Governor_OutOfBounds();
    error C3Governor_HasNotFailed();
    error C3Governor_NonceSpent(uint256);

    struct Proposal {
        bytes[] data;
        bool[] hasFailed;
    }

    function sendParams(bytes memory _data, uint256 _nonce) external;
    function sendMultiParams(bytes[] memory _data, uint256 _nonce) external;
    function doGov(uint256 _nonce, uint256 _offset) external;
    function getProposalData(uint256 _nonce, uint256 _offset) external view returns (bytes memory, bool);
    function version() external pure returns (uint256);
    function proposalLength() external view returns (uint256);
    function proposalId() external view returns (uint256);
}
