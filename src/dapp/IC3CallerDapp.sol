// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IC3CallerDapp {
    function c3Fallback(
        uint256 dappID,
        bytes calldata data,
        bytes calldata reason
    ) external returns (bool);

    function dappID() external returns (uint256);

    function isValidSender(address txSender) external returns (bool);
}
