// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {IC3Caller} from "../build/C3Caller.sol";

contract AddMPC is Script {
    function run() public {
        address mpc;
        address c3caller;

        try vm.envAddress("C3CALLER") returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert("C3CALLER not defined");
        }

        try vm.envAddress("MPC") returns (address _mpc) {
            mpc = _mpc;
        } catch {
            revert("MPC not defined");
        }

        vm.startBroadcast();
        IC3Caller(c3caller).addMPC(mpc);
        vm.stopBroadcast();
    }
}
