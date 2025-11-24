// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";

interface ITestERC20 is IERC20 {
    error OnlyAuthorized(C3ErrorParam, C3ErrorParam);

    function decimals() external view returns (uint8);
    function print(address _to, uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;
    function burn(address _from) external;
    function admin() external view returns (address);
}
