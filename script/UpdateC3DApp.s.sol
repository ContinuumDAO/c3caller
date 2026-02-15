// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import { Script } from "forge-std/Script.sol";
import { Config } from "forge-std/Config.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { C3DAppManager } from "../build/dapp/C3DAppManager.sol";

contract UpdateC3DApp is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", false);

        uint256 chainId = block.chainid;
        console.log("Updating DApp config on chain:", chainId);


        address dappManagerAddr = config.get("dappManager").toAddress();
        // Fee token from env (set by helper via get-fee-config.js: FEE_TOKEN, PAYLOAD_PER_BYTE_FEE, GAS_PER_ETHER_FEE)
        address feeToken = vm.envAddress("FEE_TOKEN");
        string memory dappKey = config.get("dapp_key").toString();
        string memory metadata = config.get("metadata").toString();

        C3DAppManager dappManager = C3DAppManager(dappManagerAddr);

        
        address admin = dappManager.dappKeyCreator(dappKey);
        uint256 dappID = dappManager.deriveDAppID(admin, dappKey);

        (, address oldFeeToken,,,) = dappManager.dappConfig(dappID);
        if (oldFeeToken != feeToken) {
            vm.startBroadcast();
            dappManager.removeFeeConfig(oldFeeToken);

            // setFeeConfig must run before updateDAppConfig (updateDAppConfig depends on it). Env vars from get-fee-config.js.
            uint256 payloadPerByteFee = vm.envOr("PAYLOAD_PER_BYTE_FEE", uint256(0));
            uint256 gasPerEtherFee = vm.envOr("GAS_PER_ETHER_FEE", uint256(0));
            if (payloadPerByteFee != 0 && gasPerEtherFee != 0) {
                dappManager.setFeeConfig(feeToken, payloadPerByteFee, gasPerEtherFee);
            }
            // setFeeMinimumDeposit must run before updateDAppConfig (updateDAppConfig depends on it). Env vars from get-fee-config.js.
            uint256 feeMinimumDeposit = vm.envOr("FEE_MINIMUM_DEPOSIT", uint256(0));
            if (feeMinimumDeposit != 0) {
                dappManager.setFeeMinimumDeposit(feeToken, feeMinimumDeposit);
            }
            // Can be called by gov or admin
            dappManager.updateDAppConfig(dappID, admin, feeToken, metadata);

            // Deposit new fee token
            uint256 depositAmount = vm.envOr("DEPOSIT_AMOUNT", uint256(0));
            if (depositAmount != 0) {
                IERC20(feeToken).approve(address(dappManager), depositAmount);
                dappManager.deposit(dappID, feeToken, depositAmount);
            }

            vm.stopBroadcast();
        }

        console.log("updateDAppConfig done for dapp_key:", dappKey);
    }
}

