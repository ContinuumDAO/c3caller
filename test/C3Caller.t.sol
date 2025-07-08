// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";

import {C3UUIDKeeper} from "../src/uuid/C3UUIDKeeper.sol";
import {C3Caller} from "../src/C3Caller.sol";

contract C3CallerTest is Test {
    address gov;

    C3UUIDKeeper c3UUIDKeeper;
    C3Caller c3caller;

    function setUp() public {
        gov = makeAddr("gov");

        address c3UUIDKeeperAddress = Upgrades.deployUUPSProxy(
            "C3UUIDKeeper.sol",
            abi.encodeCall(C3UUIDKeeper.initialize, (gov))
        );
        c3UUIDKeeper = C3UUIDKeeper(c3UUIDKeeperAddress);

        address c3callerAddress = Upgrades.deployUUPSProxy(
            "C3Caller.sol",
            abi.encodeCall(C3Caller.initialize, (address(c3UUIDKeeper)))
        );
        c3caller = C3Caller(c3callerAddress);
    }

    function test_deploy() public {

    }
}
