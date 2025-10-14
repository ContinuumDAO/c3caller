// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IC3DAppManager } from "../../dapp/IC3DAppManager.sol";
import { C3ErrorParam } from "../../utils/C3CallerUtils.sol";
import { C3GovClientUpgradeable } from "../gov/C3GovClientUpgradeable.sol";

/**
 * @title C3DAppManagerUpgradeable
 * @dev Upgradeable contract for managing DApp configurations, fees, and MPC addresses in the C3 protocol.
 * This contract provides comprehensive management functionality for DApps including
 * configuration, fee management, staking pools, and MPC address management, with upgradeable capabilities.
 *
 * Key features:
 * - DApp configuration management
 * - Fee configuration and management
 * - Staking pool management
 * - MPC address and public key management
 * - Blacklist functionality
 * - Pausable and upgradeable functionality
 *
 * @notice This contract is the central management hub for upgradeable C3 DApps
 * @author @potti ContinuumDAO
 */
contract C3DAppManagerUpgradeable is IC3DAppManager, C3GovClientUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using Strings for *;
    using SafeERC20 for IERC20;

    /// @notice The DApp identifier for this manager
    uint256 public dappID;
    /// @notice Mapping of DApp ID to DApp configuration
    mapping(uint256 => DAppConfig) public dappConfig;
    /// @notice Mapping of DApp address string to DApp ID
    mapping(string => uint256) public c3DAppAddr;
    /// @notice Mapping of DApp ID to blacklist status
    mapping(uint256 => bool) public appBlacklist;
    /// @notice Mapping of asset address to fee per byte
    mapping(address => uint256) public feeCurrencies;
    /// @notice Mapping of DApp ID and token address to staking pool balance
    mapping(uint256 => mapping(address => uint256)) public dappStakePool;
    /// @notice Mapping of chain and token address to specific chain fees
    mapping(string => mapping(address => uint256)) public speChainFees;
    /// @notice Mapping of token address to accumulated fees
    mapping(address => uint256) public fees;
    /// @notice Mapping of DApp ID and MPC address to public key
    mapping(uint256 => mapping(string => string)) public mpcPubkey;
    /// @notice Mapping of DApp ID to array of MPC addresses
    mapping(uint256 => string[]) public mpcAddrs;

    /**
     * @notice Initialize the upgradeable C3DAppManager contract
     * @dev This function can only be called once during deployment
     */
    function initialize() public initializer {
        __C3GovClient_init(msg.sender);
        __Pausable_init();
        dappID = 0;
    }

    /**
     * @dev Modifier to restrict access to governance or DApp admin
     * @param _dappID The DApp identifier
     * @notice Reverts if the caller is neither governor nor DApp admin
     */
    modifier onlyGovOrAdmin(uint256 _dappID) {
        if (msg.sender != gov() && msg.sender != dappConfig[_dappID].appAdmin) {
            revert C3DAppManager_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin);
        }
        _;
    }

    /**
     * @notice Pause the contract (governance only)
     * @dev Only the governor can call this function
     */
    function pause() public onlyGov {
        _pause();
    }

    /**
     * @notice Unpause the contract (governance only)
     * @dev Only the governor can call this function
     */
    function unpause() public onlyGov {
        _unpause();
    }

    /**
     * @notice Set blacklist status for a DApp (governance only)
     * @dev Only the governor can call this function
     * @param _dappID The DApp identifier
     * @param _flag The blacklist flag
     */
    function setBlacklists(uint256 _dappID, bool _flag) external onlyGov {
        appBlacklist[_dappID] = _flag;
        emit SetBlacklists(_dappID, _flag);
    }

    /**
     * @notice Set DApp configuration (governance only)
     * @dev Only the governor can call this function
     * @param _dappID The DApp identifier
     * @param _appAdmin The DApp admin address
     * @param _feeToken The fee token address
     * @param _appDomain The DApp domain
     * @param _email The DApp email
     * @notice Reverts if fee token is zero or domain/email is empty
     */
    function setDAppConfig(
        uint256 _dappID,
        address _appAdmin,
        address _feeToken,
        string memory _appDomain,
        string memory _email
    ) external onlyGov {
        if (_feeToken == address(0)) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }
        if (bytes(_appDomain).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.AppDomain);
        }
        if (bytes(_email).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Email);
        }

        dappConfig[_dappID] = DAppConfig({ id: _dappID, appAdmin: _appAdmin, feeToken: _feeToken, discount: 0 });

        emit SetDAppConfig(_dappID, _appAdmin, _feeToken, _appDomain, _email);
    }

    /**
     * @notice Set DApp addresses (governance or DApp admin only)
     * @dev Only governance or DApp admin can call this function
     * @param _dappID The DApp identifier
     * @param _addresses Array of DApp addresses
     */
    function setDAppAddr(uint256 _dappID, string[] memory _addresses) external onlyGovOrAdmin(_dappID) {
        for (uint256 i = 0; i < _addresses.length; i++) {
            c3DAppAddr[_addresses[i]] = _dappID;
        }
        emit SetDAppAddr(_dappID, _addresses);
    }

    /**
     * @notice Add MPC address and public key (governance or DApp admin only)
     * @dev Only governance or DApp admin can call this function
     * @param _dappID The DApp identifier
     * @param _addr The MPC address
     * @param _pubkey The MPC public key
     * @notice Reverts if DApp admin is zero, addresses are empty, or lengths don't match
     */
    function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) {
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_NotZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_addr).length != bytes(_pubkey).length) {
            revert C3DAppManager_LengthMismatch(C3ErrorParam.Address, C3ErrorParam.PubKey);
        }

        mpcPubkey[_dappID][_addr] = _pubkey;
        mpcAddrs[_dappID].push(_addr);

        emit AddMpcAddr(_dappID, _addr, _pubkey);
    }

    /**
     * @notice Delete MPC address and public key (governance or DApp admin only)
     * @dev Only governance or DApp admin can call this function
     * @param _dappID The DApp identifier
     * @param _addr The MPC address to delete
     * @param _pubkey The MPC public key to delete
     * @notice Reverts if DApp admin is zero or addresses are empty
     */
    function delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) {
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }

        mpcPubkey[_dappID][_addr] = "";

        string[] storage addrs = mpcAddrs[_dappID];
        for (uint256 i = 0; i < addrs.length; i++) {
            if (keccak256(bytes(addrs[i])) == keccak256(bytes(_addr))) {
                addrs[i] = addrs[addrs.length - 1];
                addrs.pop();
                break;
            }
        }

        emit DelMpcAddr(_dappID, _addr, _pubkey);
    }

    /**
     * @notice Set fee configuration for a token and chain (governance only)
     * @dev Only the governor can call this function
     * @param _token The token address
     * @param _chain The chain identifier
     * @param _callPerByteFee The fee per byte
     * @notice Reverts if the fee is zero
     */
    function setFeeConfig(address _token, string memory _chain, uint256 _callPerByteFee) external onlyGov {
        if (_callPerByteFee == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        feeCurrencies[_token] = _callPerByteFee;
        speChainFees[_chain][_token] = _callPerByteFee;

        emit SetFeeConfig(_token, _chain, _callPerByteFee);
    }

    /**
     * @notice Deposit tokens to a DApp's staking pool
     * @param _dappID The DApp identifier
     * @param _token The token address
     * @param _amount The amount to deposit
     * @notice Reverts if the amount is zero
     * BUG: #16 Pausable Bypass in C3DAppManager
     * PASSED: (also present in C3DAppManagerUpgradeable) added whenNotPaused modifier
     */
    function deposit(uint256 _dappID, address _token, uint256 _amount) external whenNotPaused {
        if (_amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        dappStakePool[_dappID][_token] += _amount;

        emit Deposit(_dappID, _token, _amount, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Withdraw tokens from a DApp's staking pool (governance or DApp admin only)
     * @dev Only governance or DApp admin can call this function
     * @param _dappID The DApp identifier
     * @param _token The token address
     * @param _amount The amount to withdraw
     * @notice Reverts if the amount is zero or insufficient balance
     * BUG: #16 Pausable Bypass in C3DAppManager
     * PASSED: (also present in C3DAppManagerUpgradeable) added whenNotPaused modifier
     */
    function withdraw(uint256 _dappID, address _token, uint256 _amount) external onlyGovOrAdmin(_dappID) whenNotPaused {
        if (_amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        if (dappStakePool[_dappID][_token] < _amount) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        dappStakePool[_dappID][_token] -= _amount;

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdraw(_dappID, _token, _amount, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Charge fees from a DApp's staking pool (governance or DApp admin only)
     * @dev Only governance or DApp admin can call this function
     * @param _dappID The DApp identifier
     * @param _token The token address
     * @param _bill The amount to charge
     * @notice Reverts if the bill is zero or insufficient balance
     * BUG: #16 Pausable Bypass in C3DAppManager
     * PASSED: (also present in C3DAppManagerUpgradeable) added whenNotPaused modifier
     */
    function charging(uint256 _dappID, address _token, uint256 _bill) external onlyGovOrAdmin(_dappID) whenNotPaused {
        if (_bill == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        if (dappStakePool[_dappID][_token] < _bill) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        dappStakePool[_dappID][_token] -= _bill;

        emit Charging(_dappID, _token, _bill, _bill, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Get DApp configuration
     * @param _dappID The DApp identifier
     * @return The DApp configuration
     */
    function getDAppConfig(uint256 _dappID) external view returns (DAppConfig memory) {
        return dappConfig[_dappID];
    }

    /**
     * @notice Get MPC addresses for a DApp
     * @param _dappID The DApp identifier
     * @return Array of MPC addresses
     */
    function getMpcAddrs(uint256 _dappID) external view returns (string[] memory) {
        return mpcAddrs[_dappID];
    }

    /**
     * @notice Get MPC public key for a DApp and address
     * @param _dappID The DApp identifier
     * @param _addr The MPC address
     * @return The MPC public key
     */
    function getMpcPubkey(uint256 _dappID, string memory _addr) external view returns (string memory) {
        return mpcPubkey[_dappID][_addr];
    }

    /**
     * @notice Get fee currency for a token
     * @param _token The token address
     * @return The fee per byte for the token
     */
    function getFeeCurrency(address _token) external view returns (uint256) {
        return feeCurrencies[_token];
    }

    /**
     * @notice Get specific chain fee for a token
     * @param _chain The chain identifier
     * @param _token The token address
     * @return The fee per byte for the token on the specific chain
     */
    function getSpeChainFee(string memory _chain, address _token) external view returns (uint256) {
        return speChainFees[_chain][_token];
    }

    /**
     * @notice Get DApp staking pool balance
     * @param _dappID The DApp identifier
     * @param _token The token address
     * @return The staking pool balance
     */
    function getDAppStakePool(uint256 _dappID, address _token) external view returns (uint256) {
        return dappStakePool[_dappID][_token];
    }

    /**
     * @notice Get accumulated fees for a token
     * @param _token The token address
     * @return The accumulated fees
     */
    function getFee(address _token) external view returns (uint256) {
        return fees[_token];
    }

    /**
     * @notice Set accumulated fees for a token (governance only)
     * @dev Only the governor can call this function
     * @param _token The token address
     * @param _fee The fee amount
     */
    function setFee(address _token, uint256 _fee) external onlyGov {
        fees[_token] = _fee;
    }

    /**
     * @notice Set the DApp ID for this manager (governance only)
     * @dev Only the governor can call this function
     * @param _dappID The DApp identifier
     */
    function setDAppID(uint256 _dappID) external onlyGov {
        dappID = _dappID;
    }

    /**
     * @notice Set DApp configuration discount (governance or DApp admin only)
     * @dev Only governance or DApp admin can call this function
     * @param _dappID The DApp identifier
     * @param _discount The discount amount
     * @notice Reverts if DApp ID is zero or discount is zero
     */
    function setDAppConfigDiscount(uint256 _dappID, uint256 _discount) external onlyGovOrAdmin(_dappID) {
        if (_dappID == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.DAppID);
        }
        if (_discount == 0) {
            revert C3DAppManager_LengthMismatch(C3ErrorParam.DAppID, C3ErrorParam.Token);
        }

        dappConfig[_dappID].discount = _discount;
    }

    /**
     * @dev Internal function to authorize upgrades
     * @param newImplementation The new implementation address
     * @notice Only governance can authorize upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyGov { }
}
