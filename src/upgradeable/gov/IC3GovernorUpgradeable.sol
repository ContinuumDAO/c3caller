// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3Governor} from "../../gov/IC3Governor.sol";

interface IC3GovernorUpgradeable is IC3Governor {
    function initialize(address _gov, address _c3CallerProxy, uint256 _dappID) external;
}
