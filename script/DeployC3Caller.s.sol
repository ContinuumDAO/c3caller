// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {C3UUIDKeeperUpgradeable} from "../build/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {C3CallerUpgradeable} from "../build/upgradeable/C3CallerUpgradeable.sol";
import {C3DAppManagerUpgradeable} from "../build/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {C3CallerProxy} from "../build/utils/C3CallerProxy.sol";

contract DeployC3Caller is Script {
    function run() public {
        vm.startBroadcast();

        C3UUIDKeeperUpgradeable c3UUIDKeeperImpl = new C3UUIDKeeperUpgradeable();
        bytes memory c3UUIDKeeperInitData = abi.encodeWithSignature("initialize()");
        address c3UUIDKeeper = address(new C3CallerProxy(address(c3UUIDKeeperImpl), c3UUIDKeeperInitData));
        console.log("C3UUIDKeeper", c3UUIDKeeper);

        C3CallerUpgradeable c3callerImpl = new C3CallerUpgradeable();
        bytes memory c3callerInitData = abi.encodeWithSignature("initialize(address)", c3UUIDKeeper);
        address c3caller = address(new C3CallerProxy(address(c3callerImpl), c3callerInitData));
        console.log("C3Caller", c3caller);

        C3DAppManagerUpgradeable c3DAppManagerImpl = new C3DAppManagerUpgradeable();
        bytes memory c3DAppManagerInitData = abi.encodeWithSignature("initialize()");
        address c3DAppManager = address(new C3CallerProxy(address(c3DAppManagerImpl), c3DAppManagerInitData));
        console.log("C3DAppManager", c3DAppManager);

        vm.stopBroadcast();
    }
}
