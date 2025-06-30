// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

interface ITheiaERC20 {
    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function mint(address to, uint256 amount) external returns (bool);

    function burn(address from, uint256 amount) external returns (bool);

    function setMinter(address _auth) external;

    function applyMinter() external;

    function revokeMinter(address _auth) external;

    function depositVault(
        uint256 amount,
        address to
    ) external returns (uint256);

    function withdrawVault(
        address from,
        uint256 amount,
        address to
    ) external returns (uint256);

    function underlying() external view returns (address);

    function deposit(uint256 amount, address to) external returns (uint256);

    function withdraw(uint256 amount, address to) external returns (uint256);
}

interface IERC20Extended {
    function decimals() external view returns (uint8);
}
