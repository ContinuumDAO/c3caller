// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {C3UUIDKeeper} from "../build/uuid/C3UUIDKeeper.sol";
import {C3DAppManager} from "../build/dapp/C3DAppManager.sol";
import {C3Caller} from "../build/C3Caller.sol";

contract DeployC3Caller is Script {
    function run() public {
        vm.startBroadcast();

        // Deploy UUID Keeper
        C3UUIDKeeper uuidKeeper = new C3UUIDKeeper();
        console.log("C3UUIDKeeper:", address(uuidKeeper));

        // Deploy DApp Manager
        C3DAppManager dappManager = new C3DAppManager();
        console.log("C3DAppManager:", address(dappManager));

        // Deploy core C3Caller
        C3Caller c3caller = new C3Caller(address(uuidKeeper), address(dappManager));
        console.log("C3Caller:", address(c3caller));

        // Set C3Caller in UUID Keeper and DApp Manager
        uuidKeeper.setC3Caller(address(c3caller));
        dappManager.setC3Caller(address(c3caller));

        vm.stopBroadcast();
    }
}
