// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3GovernDApp} from "../../../src/gov/C3GovernDApp.sol";

contract MockC3GovernDApp is C3GovernDApp {
    bool public shouldRevert;
    uint256 failCount = 0;

    constructor(
        address _gov,
        address _c3callerProxy,
        address _txSender,
        uint256 _dappID
    ) C3GovernDApp(_gov, _c3callerProxy, _txSender, _dappID) {
        shouldRevert = false;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function _c3Fallback(bytes4 /*_selector*/, bytes calldata /*_data*/, bytes calldata /*_reason*/)
        internal
        override
        returns (bool)
    {
        if (shouldRevert) {
            revert("MockC3GovernDApp: intentional revert");
        }
        failCount++;
        return true;
    }
} 
