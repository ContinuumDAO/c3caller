// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Uint} from "../utils/C3CallerUtils.sol";

interface IC3Governor {
    event NewProposal(bytes32 indexed uuid);

    // TODO: add isGov bool
    event C3GovernorLog(bytes32 indexed nonce, uint256 indexed toChainID, string to, bytes toData);

    event LogChangeMPC(address indexed oldMPC, address indexed newMPC, uint256 indexed effectiveTime, uint256 chainID);

    event LogFallback(bytes4 selector, bytes data, bytes reason);
    event LogChangeGov(address _gov, address gov);
    event LogSendParams(address target, uint256 chainId, bytes dataXChain);

    error C3Governor_InvalidLength(Uint);
    error C3Governor_OutOfBounds();
    error C3Governor_HasNotFailed();

    function sendParams(bytes memory _data, bytes32 _nonce) external;
    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external;
    function doGov(bytes32 _nonce, uint256 offset) external;
    function getProposalData(bytes32 _nonce, uint256 offset) external view returns (bytes memory, bool);
    function version() external pure returns (uint256);
}
