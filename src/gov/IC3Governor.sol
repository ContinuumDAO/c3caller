// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

interface IC3Governor {
    event NewProposal(bytes32 indexed uuid);

    // TODO: add isGov bool
    event C3GovernorLog(bytes32 indexed nonce, uint256 indexed toChainID, string to, bytes toData);

    function sendParams(bytes memory _data, bytes32 _nonce) external;
    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external;
    function doGov(bytes32 _nonce, uint256 offset) external;
    function getProposalData(bytes32 _nonce, uint256 offset) external view returns (bytes memory, bool);
    function version() external pure returns (uint256);
}
