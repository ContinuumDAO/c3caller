// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IC3GovClient} from "../build/gov/C3GovClient.sol";

contract GetAllOperators is Script {
    function run() public {
        address newOperator;
        address c3caller;

        try vm.envAddress("C3CALLER") returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert("C3CALLER not defined");
        }

        // address[] memory operators = IC3GovClient(c3caller).getAllOperators();

        // for (uint8 i = 0; i < operators.length; i++) {
        //     console.log(operators[i]);
        // }
    }
}
