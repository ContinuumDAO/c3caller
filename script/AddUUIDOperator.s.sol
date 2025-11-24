// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {IC3GovClient} from "../build/gov/C3GovClient.sol";

contract AddUUIDOperator is Script {
    address c3caller;
    address c3UUIDKeeper;

    function run() public {
        try vm.envAddress("C3CALLER") returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert("C3CALLER not defined");
        }

        try vm.envAddress("C3_UUID_KEEPER") returns (address _c3UUIDKeeper) {
            c3UUIDKeeper = _c3UUIDKeeper;
        } catch {
            revert("C3_UUID_KEEPER not defined");
        }

        vm.startBroadcast();
        // IC3GovClient(c3UUIDKeeper).addOperator(c3caller);
        vm.stopBroadcast();
    }
}
