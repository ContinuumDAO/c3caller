// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3GovernDapp} from "../../src/gov/C3GovernDapp.sol";

contract MockC3GovernDapp is C3GovernDapp {
    bool public shouldRevert;

    constructor(
        address _gov,
        address _c3callerProxy,
        address _txSender,
        uint256 _dappID
    ) C3GovernDapp(_gov, _c3callerProxy, _txSender, _dappID) {
        shouldRevert = false;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        override
        returns (bool)
    {
        if (shouldRevert) {
            revert("MockC3GovernDapp: intentional revert");
        }
        return true;
    }
} 