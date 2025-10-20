// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3UUIDKeeper} from "../../uuid/IC3UUIDKeeper.sol";

interface IC3UUIDKeeperUpgradeable is IC3UUIDKeeper {
    function initialize() external;
}
