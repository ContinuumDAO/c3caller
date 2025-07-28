// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { ITestERC20, Address } from "./ITestERC20.sol";

contract TestERC20 is ITestERC20, ERC20 {
    uint8 public _decimals;
    address public admin;

    constructor (string memory _name, string memory _symbol, uint8 decimals_) ERC20(_name, _symbol) {
        _decimals = decimals_;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert OnlyAuthorized(Address.Sender, Address.Admin);
        }
        _;
    }

    function print(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mint(address to, uint256 amount) external onlyAdmin {
        _mint(to, amount);
    }

    function burn(address from) external onlyAdmin {
        _burn(from, balanceOf(from));
    }

    function decimals() public override(ITestERC20, ERC20) view returns (uint8) {
        return _decimals;
    }
}
