// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3Caller} from "../IC3Caller.sol";

interface IC3CallerUpgradeable is IC3Caller {
    function initialize(address _uuidKeeper, address _dappManager) external;
}
