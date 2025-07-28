// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Upgrades } from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import { Test } from "forge-std/Test.sol";

import { C3Caller } from "../src/C3Caller.sol";
import { C3UUIDKeeper } from "../src/uuid/C3UUIDKeeper.sol";

contract C3CallerTest is Test {}
