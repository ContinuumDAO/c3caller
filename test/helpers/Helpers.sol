// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {Accounts} from "./Accounts.sol";
import {Deployer} from "./Deployer.sol";

contract Helpers is Test, Accounts, Deployer {
    function setUp() public virtual {
        (admin, gov, treasury, user1, user2, mpc1, mpc2) =
            abi.decode(abi.encode(_getAccounts()), (address, address, address, address, address, address, address));

        (ctm, usdc) = _deployFeeTokens();

        vm.deal(admin, 100 ether);
        vm.deal(gov, 100 ether);
        vm.deal(mpc1, 100 ether);
        vm.deal(mpc2, 100 ether);

        _dealAllERC20(address(usdc), _100_000_000);
        _dealAllERC20(address(ctm), _100_000_000);
    }
}
