// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {IC3GovClient} from "../build/gov/C3GovClient.sol";

contract NewOperator is Script {
    function run() public {
        address newOperator;
        address c3caller;

        try vm.envAddress("C3CALLER") returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert("C3CALLER not defined");
        }

        try vm.envAddress("NEW_OPERATOR") returns (address _newOperator) {
            newOperator = _newOperator;
        } catch {
            revert("NEW_OPERATOR not defined");
        }

        vm.startBroadcast();
        IC3GovClient(c3caller).addOperator(newOperator);
        vm.stopBroadcast();
    }
}
