// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { C3ErrorParam } from "./C3CallerUtils.sol";
import { ITestERC20 } from "./ITestERC20.sol";

/**
 * @title TestERC20
 * @dev Test ERC20 token contract for C3 protocol testing purposes.
 * This contract extends the standard ERC20 implementation with additional
 * functionality for testing cross-chain operations and fee mechanisms.
 * 
 * Features:
 * - Standard ERC20 functionality
 * - Configurable decimals
 * - Admin-controlled minting and burning
 * - Public minting for testing
 * 
 * @notice This contract is intended for testing purposes only
 * @author @potti ContinuumDAO
 */
contract TestERC20 is ITestERC20, ERC20 {
    /// @notice The number of decimals for the token
    uint8 public _decimals;
    
    /// @notice The admin address with special privileges
    address public admin;

    /**
     * @dev Constructor for TestERC20
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param decimals_ The number of decimals for the token
     */
    constructor(string memory _name, string memory _symbol, uint8 decimals_) ERC20(_name, _symbol) {
        _decimals = decimals_;
    }

    /**
     * @dev Modifier to restrict access to admin only
     * @notice Reverts if the caller is not the admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Admin);
        }
        _;
    }

    /**
     * @notice Mint tokens to a specified address (public function for testing)
     * @dev Anyone can call this function to mint tokens for testing purposes
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function print(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    /**
     * @notice Mint tokens to a specified address (admin only)
     * @dev Only the admin can call this function
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyAdmin {
        _mint(_to, _amount);
    }

    /**
     * @notice Burn all tokens from a specified address (admin only)
     * @dev Only the admin can call this function
     * @param _from The address to burn tokens from
     */
    function burn(address _from) external onlyAdmin {
        _burn(_from, balanceOf(_from));
    }

    /**
     * @notice Get the number of decimals for the token
     * @return The number of decimals
     */
    function decimals() public view override(ITestERC20, ERC20) returns (uint8) {
        return _decimals;
    }
}
