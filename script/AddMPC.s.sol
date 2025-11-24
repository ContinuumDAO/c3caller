// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {IC3GovClient} from "../build/gov/C3GovClient.sol";

contract AddMPC is Script {
    function run() public {
        address mpc1;
        address mpc2;
        address c3UUIDKeeper;
        address c3caller;
        address c3DAppManager;

        try vm.envAddress("MPC1") returns (address _mpc1) {
            mpc1 = _mpc1;
        } catch {
            revert("MPC1 not defined");
        }

        try vm.envAddress("MPC2") returns (address _mpc2) {
            mpc2 = _mpc2;
        } catch {
            revert("MPC2 not defined");
        }

        try vm.envAddress("C3_UUID_KEEPER") returns (address _c3UUIDKeeper) {
            c3UUIDKeeper = _c3UUIDKeeper;
        } catch {
            revert("C3_UUID_KEEPER not defined");
        }

        try vm.envAddress("C3CALLER") returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert("C3CALLER not defined");
        }

        try vm.envAddress("C3_DAPP_MANAGER") returns (address _c3DAppManager) {
            c3DAppManager = _c3DAppManager;
        } catch {
            revert("C3_DAPP_MANAGER not defined");
        }

        vm.startBroadcast();
        // IC3GovClient(c3UUIDKeeper).addOperator(mpc1);
        // IC3GovClient(c3UUIDKeeper).addOperator(mpc2);

        // IC3GovClient(c3caller).addOperator(mpc1);
        // IC3GovClient(c3caller).addOperator(mpc2);

        // IC3GovClient(c3DAppManager).addOperator(mpc1);
        // IC3GovClient(c3DAppManager).addOperator(mpc2);
        vm.stopBroadcast();
    }
}
