// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { C3Caller } from "../../src/C3Caller.sol";
import { C3CallerUpgradeable } from "../../src/upgradeable/C3CallerUpgradeable.sol";
import { C3UUIDKeeperUpgradeable } from "../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import { C3UUIDKeeper } from "../../src/uuid/C3UUIDKeeper.sol";

import { Utils } from "./Utils.sol";

contract Deployer is Utils {
    // C3UUIDKeeper c3UUIDKeeper;
    // C3Caller c3caller;

    // function _deployC3Caller() internal {
    //     address c3UUIDKeeperImpl = address(new C3UUIDKeeperUpgradeable());
    //     c3UUIDKeeper =
    //         C3UUIDKeeper(_deployProxy(c3UUIDKeeperImpl, abi.encodeCall(C3UUIDKeeperUpgradeable.initialize, ())));
    //     address c3callerImpl = address(new C3CallerUpgradeable());
    //     c3caller = C3Caller(
    //         _deployProxy(c3callerImpl, abi.encodeCall(C3CallerUpgradeable.initialize, (address(c3UUIDKeeper))))
    //     );
    // }
}
