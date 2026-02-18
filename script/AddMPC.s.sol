// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import { Script } from "forge-std/Script.sol";
import { Config } from "forge-std/Config.sol";
import { console } from "forge-std/console.sol";
import { IC3Caller } from "../build/C3Caller.sol";

/**
 * Calls C3Caller.addMPC(mpc). C3Caller address from deployments.toml for current chain.
 * Env: MPC (address to add as MPC). Optional C3CALLER overrides deployments.toml.
 */
contract AddMPC is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", false);

        address c3callerAddr;
        try vm.envAddress("C3CALLER") returns (address _addr) {
            c3callerAddr = _addr;
        } catch {
            c3callerAddr = config.get("c3caller").toAddress();
        }

        address mpc = vm.envAddress("MPC");

        if (IC3Caller(c3callerAddr).isMPCAddr(mpc)) {
            console.log("MPC already added, skipping:", mpc);
            return;
        }

        vm.startBroadcast();
        IC3Caller(c3callerAddr).addMPC(mpc);
        vm.stopBroadcast();
    }
}
