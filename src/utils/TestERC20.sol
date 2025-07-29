// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Address, ITestERC20 } from "./ITestERC20.sol";

contract TestERC20 is ITestERC20, ERC20 {
    uint8 public _decimals;
    address public admin;

    constructor(string memory _name, string memory _symbol, uint8 decimals_) ERC20(_name, _symbol) {
        _decimals = decimals_;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert OnlyAuthorized(Address.Sender, Address.Admin);
        }
        _;
    }

    function print(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function mint(address _to, uint256 _amount) external onlyAdmin {
        _mint(_to, _amount);
    }

    function burn(address _from) external onlyAdmin {
        _burn(_from, balanceOf(_from));
    }

    function decimals() public view override(ITestERC20, ERC20) returns (uint8) {
        return _decimals;
    }
}
