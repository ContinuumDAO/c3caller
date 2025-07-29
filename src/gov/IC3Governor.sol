// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Uint } from "../utils/C3CallerUtils.sol";

interface IC3Governor {
    event NewProposal(bytes32 indexed uuid);

    // TODO: add isGov bool
    event C3GovernorLog(bytes32 indexed _nonce, uint256 indexed _toChainID, string _to, bytes _toData);

    event LogChangeMPC(
        address indexed _oldMPC, address indexed _newMPC, uint256 indexed _effectiveTime, uint256 _chainID
    );

    event LogFallback(bytes4 _selector, bytes _data, bytes _reason);
    event LogChangeGov(address _gov, address _newGov);
    event LogSendParams(address _target, uint256 _chainId, bytes _dataXChain);

    error C3Governor_InvalidLength(Uint);
    error C3Governor_OutOfBounds();
    error C3Governor_HasNotFailed();

    function sendParams(bytes memory _data, bytes32 _nonce) external;
    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external;
    function doGov(bytes32 _nonce, uint256 _offset) external;
    function getProposalData(bytes32 _nonce, uint256 _offset) external view returns (bytes memory, bool);
    function version() external pure returns (uint256);
}
