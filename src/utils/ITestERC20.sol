// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum Address {
    Sender,
    Admin
}

interface ITestERC20 is IERC20 {
    error OnlyAuthorized(Address, Address);

    function decimals() external view returns (uint8);
    function print(address _to, uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;
    function burn(address _from) external;
}
