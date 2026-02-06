// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSD is ERC20 {
    constructor (address sender) ERC20("Test USD", "TUSD") {
        _mint(sender, 100_000_000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract DeployFeeToken is Script {
    function run() public {
        vm.startBroadcast();
        TestUSD testUSD = new TestUSD(msg.sender);
        vm.stopBroadcast();

        console.log("Test USD deployed to ");
        console.log(address(testUSD));
    }
}
