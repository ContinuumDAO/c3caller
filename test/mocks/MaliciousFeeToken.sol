// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {C3DAppManager} from "../../src/dapp/C3DAppManager.sol";

// Mock malicious ERC20 token that can reenter
contract MaliciousFeeToken is IERC20 {
    C3DAppManager public dappManager;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public reentering = false;

    constructor(C3DAppManager _dappManager) {
        dappManager = _dappManager;
        totalSupply = 1000000;
        balanceOf[address(this)] = 1000000;
    }

    function transfer(
        address to,
        uint256 /*amount*/
    )
        external
        returns (bool)
    {
        if (reentering && to == address(dappManager)) {
            // Try to reenter the withdraw function
            dappManager.withdraw(1, address(this));
        }
        return true;
    }

    function transferFrom(
        address,
        /*from*/
        address,
        /*to*/
        uint256 /*amount*/
    )
        external
        pure
        returns (bool)
    {
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function setReentering(bool _reentering) external {
        reentering = _reentering;
    }
}

