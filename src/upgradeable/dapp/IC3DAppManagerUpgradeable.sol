// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3DAppManager} from "../../dapp/IC3DAppManager.sol";

interface IC3DAppManagerUpgradeable is IC3DAppManager {
    function initialize() external;
}
