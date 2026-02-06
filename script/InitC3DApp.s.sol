// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import { Script } from "forge-std/Script.sol";
import { Config } from "forge-std/Config.sol";
import { console } from "forge-std/console.sol";

import { C3DAppManager } from "../build/dapp/C3DAppManager.sol";

contract InitC3DApp is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", false);

        uint256 chainId = block.chainid;
        console.log("Initing DApp config on chain:", chainId);

        address dappManagerAddr = config.get("dappManager").toAddress();
        address feeToken = config.get("fee_token").toAddress();
        string memory dappKey = config.get("dapp_key").toString();
        string memory metadata = config.get("metadata").toString();

        C3DAppManager dappManager = C3DAppManager(dappManagerAddr);

        vm.startBroadcast();
        dappManager.initDAppConfig(dappKey, feeToken, metadata);
        vm.stopBroadcast();

        console.log("initDAppConfig done for dapp_key:", dappKey);
    }
}
