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
        // Primary fee token = first address in [[chainId.fee_tokens]] (fee_token field no longer exists)
        string memory tomlContent = vm.resolveEnv(vm.readFile("./deployments.toml"));
        address feeToken = vm.parseTomlAddress(tomlContent, string.concat("$.", vm.toString(chainId), ".fee_tokens.0.address"));
        string memory dappKey = config.get("dapp_key").toString();
        string memory metadata = config.get("metadata").toString();

        C3DAppManager dappManager = C3DAppManager(dappManagerAddr);

        vm.startBroadcast();
        // setFeeConfig must run before initDAppConfig (initDAppConfig depends on it). Env vars from get-fee-config.js.
        uint256 payloadPerByteFee = vm.envOr("PAYLOAD_PER_BYTE_FEE", uint256(0));
        uint256 gasPerEtherFee = vm.envOr("GAS_PER_ETHER_FEE", uint256(0));
        if (payloadPerByteFee != 0 && gasPerEtherFee != 0) {
            dappManager.setFeeConfig(feeToken, payloadPerByteFee, gasPerEtherFee);
        }
        dappManager.initDAppConfig(dappKey, feeToken, metadata);
        vm.stopBroadcast();

        console.log("initDAppConfig done for dapp_key:", dappKey);
    }
}
