// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";

interface IC3CallerDApp {
    error C3CallerDApp_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3CallerDApp_InvalidDAppID(uint256, uint256);

    function c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason) external returns (bool);
    function isValidSender(address _txSender) external view returns (bool);
    function c3CallerProxy() external view returns (address);
    function dappID() external view returns (uint256);
}
