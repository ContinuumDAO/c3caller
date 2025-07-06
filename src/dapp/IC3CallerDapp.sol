// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

interface IC3CallerDapp {
    function c3Fallback(uint256 dappID, bytes calldata data, bytes calldata reason) external returns (bool);

    function dappID() external returns (uint256);

    function isValidSender(address txSender) external view returns (bool);
}
