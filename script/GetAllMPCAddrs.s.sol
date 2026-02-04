// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IC3Caller} from "../build/C3Caller.sol";

contract GetAllMPCAddrs is Script {
    function run() public view {
        address c3caller;

        try vm.envAddress("C3CALLER") returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert("C3CALLER not defined");
        }

        address[] memory operators = IC3Caller(c3caller).getAllMPCAddrs();

        for (uint8 i = 0; i < operators.length; i++) {
            console.log(operators[i]);
        }
    }
}
