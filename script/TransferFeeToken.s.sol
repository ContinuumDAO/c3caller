// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract TransferFeeToken is Script {
    address receiver = 0xa55E7E6dCEBD02eA56d2f268fA22A50C807D759f;
    address feeToken = 0x375E2A148102bF179AE7743A28A34cF959bE9499;

    function run() public {
        vm.startBroadcast();
        // transfer is from msg.sender (forge default sender, set by --account) to receiver
        IERC20(feeToken).transferFrom(msg.sender, receiver, 100_000_000 * 10 ** 6);
        vm.stopBroadcast();

        console.log("Fee token transferred");
    }
}
