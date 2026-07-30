// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";
import {IC3Caller} from "../build/C3Caller.sol";

/**
 * Calls C3Caller.activateChainID or C3Caller.deactivateChainID for each chain ID in CHAIN_IDS.
 * C3Caller address is read from deployments.toml (current chain). Skips chain IDs already in target state.
 * Env: CHAIN_IDS (comma-separated chain ID strings), ACTIVE_STATUS (true|false).
 */
contract SetActiveStatus is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", false);

        uint256 chainId = block.chainid;
        console.log("SetActiveStatus on chain:", chainId);

        address c3callerAddr = config.get("c3caller").toAddress();
        string[] memory chainIds = vm.envString("CHAIN_IDS", ",");
        bool active = vm.envBool("ACTIVE_STATUS");

        IC3Caller c3caller = IC3Caller(c3callerAddr);

        for (uint256 i = 0; i < chainIds.length; i++) {
            string memory chainIdStr = chainIds[i];
            bool currentlyActive = c3caller.isActiveChainID(chainIdStr);
            if (active && currentlyActive) {
                console.log("skip (already active):", chainIdStr);
                continue;
            }
            if (!active && !currentlyActive) {
                console.log("skip (already inactive):", chainIdStr);
                continue;
            }
            vm.startBroadcast();
            if (active) {
                c3caller.activateChainID(chainIdStr);
                console.log("activateChainID:", chainIdStr);
            } else {
                c3caller.deactivateChainID(chainIdStr);
                console.log("deactivateChainID:", chainIdStr);
            }
            vm.stopBroadcast();
        }
    }
}
