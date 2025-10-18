// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract CalculateUUPSStorage is Script {
    string uupsKey;

    function calc(string memory key) public pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(key))) - 1)) & ~bytes32(uint256(0xff));
    }

    function run() public pure {
        string memory c3callerdapp = "c3caller.storage.C3CallerDApp";
        string memory c3governdapp = "c3caller.storage.C3GovernDApp";
        string memory c3govclient = "c3caller.storage.C3GovClient";

        bytes32 c3callerdappkey = calc(c3callerdapp);
        bytes32 c3governdappkey = calc(c3governdapp);
        bytes32 c3govclientkey = calc(c3govclient);

        console.log("C3CallerDApp:");
        console.logBytes32(c3callerdappkey);
        console.log("C3GovernDApp:");
        console.logBytes32(c3governdappkey);
        console.log("C3GovClient:");
        console.logBytes32(c3govclientkey);
    }
}
