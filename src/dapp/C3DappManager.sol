// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3GovClient } from "../gov/C3GovClient.sol";
import { C3ErrorParam } from "../utils/C3CallerUtils.sol";
import { IC3DAppManager } from "./IC3DappManager.sol";

/**
 * @title C3DappManager
 * @dev Contract for managing dApp configurations, fees, and MPC addresses in the C3 protocol.
 * This contract provides comprehensive management functionality for dApps including
 * configuration, fee management, staking pools, and MPC address management.
 * 
 * Key features:
 * - dApp configuration management
 * - Fee configuration and management
 * - Staking pool management
 * - MPC address and public key management
 * - Blacklist functionality
 * - Pausable functionality for emergency stops
 * 
 * @notice This contract is the central management hub for C3 dApps
 * @author @potti ContinuumDAO
 */
contract C3DappManager is IC3DAppManager, C3GovClient, Pausable {
    using Strings for *;
    using SafeERC20 for IERC20;

    /// @notice The dApp identifier for this manager
    uint256 public dappID;

    /// @notice Mapping of dApp ID to dApp configuration
    mapping(uint256 => DappConfig) private dappConfig;
    
    /// @notice Mapping of dApp address string to dApp ID
    mapping(string => uint256) public c3DappAddr;
    
    /// @notice Mapping of dApp ID to blacklist status
    mapping(uint256 => bool) public appBlacklist;

    /// @notice Mapping of asset address to fee per byte
    mapping(address => uint256) public feeCurrencies;
    
    /// @notice Mapping of dApp ID and token address to staking pool balance
    mapping(uint256 => mapping(address => uint256)) public dappStakePool;

    /// @notice Mapping of chain and token address to specific chain fees
    mapping(string => mapping(address => uint256)) public speChainFees;

    /// @notice Mapping of token address to accumulated fees
    mapping(address => uint256) private fees;

    /// @notice Mapping of dApp ID and MPC address to public key
    mapping(uint256 => mapping(string => string)) public mpcPubkey;
    
    /// @notice Mapping of dApp ID to array of MPC addresses
    mapping(uint256 => string[]) public mpcAddrs;

    /**
     * @dev Constructor for C3DappManager
     * @notice Initializes the contract with the deployer as governor
     */
    constructor() C3GovClient(msg.sender) {
        // C3GovClient constructor will handle the initialization
    }

    /**
     * @dev Modifier to restrict access to governance or dApp admin
     * @param _dappID The dApp identifier
     * @notice Reverts if the caller is neither governor nor dApp admin
     */
    modifier onlyGovOrAdmin(uint256 _dappID) {
        if (msg.sender != gov && msg.sender != dappConfig[_dappID].appAdmin) {
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
     * @notice Set blacklist status for a dApp (governance only)
     * @dev Only the governor can call this function
     * @param _dappID The dApp identifier
     * @param _flag The blacklist flag
     */
    function setBlacklists(uint256 _dappID, bool _flag) external onlyGov {
        appBlacklist[_dappID] = _flag;
        emit SetBlacklists(_dappID, _flag);
    }

    /**
     * @notice Set dApp configuration (governance only)
     * @dev Only the governor can call this function
     * @param _dappID The dApp identifier
     * @param _appAdmin The dApp admin address
     * @param _feeToken The fee token address
     * @param _appDomain The dApp domain
     * @param _email The dApp email
     * @notice Reverts if fee token is zero or domain/email is empty
     */
    function setDAppConfig(
        uint256 _dappID,
        address _appAdmin,
        address _feeToken,
        string memory _appDomain,
        string memory _email
    ) external onlyGov {
        // require(_feeToken != address(0), "C3DappManager: feeToken is address(0)");
        if (_feeToken == address(0)) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }
        // require(bytes(_appDomain).length > 0, "C3DappManager: appDomain is empty");
        if (bytes(_appDomain).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.AppDomain);
        }
        // require(bytes(_email).length > 0, "C3DappManager: email is empty");
        if (bytes(_email).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Email);
        }

        dappConfig[_dappID] = DappConfig({ id: _dappID, appAdmin: _appAdmin, feeToken: _feeToken, discount: 0 });

        emit SetDAppConfig(_dappID, _appAdmin, _feeToken, _appDomain, _email);
    }

    /**
     * @notice Set dApp addresses (governance or dApp admin only)
     * @dev Only governance or dApp admin can call this function
     * @param _dappID The dApp identifier
     * @param _addresses Array of dApp addresses
     */
    function setDAppAddr(uint256 _dappID, string[] memory _addresses) external onlyGovOrAdmin(_dappID) {
        for (uint256 i = 0; i < _addresses.length; i++) {
            c3DappAddr[_addresses[i]] = _dappID;
        }
        emit SetDAppAddr(_dappID, _addresses);
    }

    /**
     * @notice Add MPC address and public key (governance or dApp admin only)
     * @dev Only governance or dApp admin can call this function
     * @param _dappID The dApp identifier
     * @param _addr The MPC address
     * @param _pubkey The MPC public key
     * @notice Reverts if dApp admin is zero, addresses are empty, or lengths don't match
     */
    function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) {
        // require(_appAdmin != address(0), "C3DappManager: appAdmin is address(0)");
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        // require(bytes(_addr).length > 0, "C3DappManager: addr is empty");
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        // require(bytes(_pubkey).length > 0, "C3DappManager: pubkey is empty");
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        // require(_appAdmin != address(0), "C3DappManager: appAdmin is not address(0)");
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_NotZeroAddress(C3ErrorParam.Admin);
        }
        // require(bytes(_addr).length > 0, "C3DappManager: addr is empty");
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        // require(bytes(_pubkey).length > 0, "C3DappManager: pubkey is empty");
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        // require(bytes(_addr).length == bytes(_pubkey).length, "C3DappManager: addr and pubkey length mismatch");
        if (bytes(_addr).length != bytes(_pubkey).length) {
            revert C3DAppManager_LengthMismatch(C3ErrorParam.Address, C3ErrorParam.PubKey);
        }

        mpcPubkey[_dappID][_addr] = _pubkey;
        mpcAddrs[_dappID].push(_addr);

        emit AddMpcAddr(_dappID, _addr, _pubkey);
    }

    /**
     * @notice Delete MPC address and public key (governance or dApp admin only)
     * @dev Only governance or dApp admin can call this function
     * @param _dappID The dApp identifier
     * @param _addr The MPC address to delete
     * @param _pubkey The MPC public key to delete
     * @notice Reverts if dApp admin is zero or addresses are empty
     */
    function delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) {
        // require(_appAdmin != address(0), "C3DappManager: appAdmin is address(0)");
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        // require(bytes(_addr).length > 0, "C3DappManager: addr is empty");
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        // require(bytes(_pubkey).length > 0, "C3DappManager: pubkey is empty");
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }

        delete mpcPubkey[_dappID][_addr];

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
        // require(_callPerByteFee > 0, "C3DappManager: callPerByteFee is 0");
        if (_callPerByteFee == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        feeCurrencies[_token] = _callPerByteFee;
        speChainFees[_chain][_token] = _callPerByteFee;

        emit SetFeeConfig(_token, _chain, _callPerByteFee);
    }

    /**
     * @notice Deposit tokens to a dApp's staking pool
     * @param _dappID The dApp identifier
     * @param _token The token address
     * @param _amount The amount to deposit
     * @notice Reverts if the amount is zero
     */
    function deposit(uint256 _dappID, address _token, uint256 _amount) external {
        // require(_callPerByteFee > 0, "C3DappManager: callPerByteFee is 0");
        if (_amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        dappStakePool[_dappID][_token] += _amount;

        emit Deposit(_dappID, _token, _amount, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Withdraw tokens from a dApp's staking pool (governance or dApp admin only)
     * @dev Only governance or dApp admin can call this function
     * @param _dappID The dApp identifier
     * @param _token The token address
     * @param _amount The amount to withdraw
     * @notice Reverts if the amount is zero or insufficient balance
     */
    function withdraw(uint256 _dappID, address _token, uint256 _amount) external onlyGovOrAdmin(_dappID) {
        // require(_callPerByteFee > 0, "C3DappManager: callPerByteFee is 0");
        if (_amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        // require(dappStakePool[_dappID][_token] >= _amount, "C3DappManager: insufficient balance");
        if (dappStakePool[_dappID][_token] < _amount) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        dappStakePool[_dappID][_token] -= _amount;

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdraw(_dappID, _token, _amount, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Charge fees from a dApp's staking pool (governance or dApp admin only)
     * @dev Only governance or dApp admin can call this function
     * @param _dappID The dApp identifier
     * @param _token The token address
     * @param _bill The amount to charge
     * @notice Reverts if the bill is zero or insufficient balance
     */
    function charging(uint256 _dappID, address _token, uint256 _bill) external onlyGovOrAdmin(_dappID) {
        // require(_callPerByteFee > 0, "C3DappManager: callPerByteFee is 0");
        if (_bill == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        // require(dappStakePool[_dappID][_token] >= _bill, "C3DappManager: insufficient balance");
        if (dappStakePool[_dappID][_token] < _bill) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        dappStakePool[_dappID][_token] -= _bill;

        emit Charging(_dappID, _token, _bill, _bill, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Get dApp configuration
     * @param _dappID The dApp identifier
     * @return The dApp configuration
     */
    function getDappConfig(uint256 _dappID) external view returns (DappConfig memory) {
        return dappConfig[_dappID];
    }

    /**
     * @notice Get MPC addresses for a dApp
     * @param _dappID The dApp identifier
     * @return Array of MPC addresses
     */
    function getMpcAddrs(uint256 _dappID) external view returns (string[] memory) {
        return mpcAddrs[_dappID];
    }

    /**
     * @notice Get MPC public key for a dApp and address
     * @param _dappID The dApp identifier
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
     * @notice Get dApp staking pool balance
     * @param _dappID The dApp identifier
     * @param _token The token address
     * @return The staking pool balance
     */
    function getDappStakePool(uint256 _dappID, address _token) external view returns (uint256) {
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
     * @notice Set the dApp ID for this manager (governance only)
     * @dev Only the governor can call this function
     * @param _dappID The dApp identifier
     */
    function setDappID(uint256 _dappID) external onlyGov {
        dappID = _dappID;
    }

    /**
     * @notice Set dApp configuration discount (governance or dApp admin only)
     * @dev Only governance or dApp admin can call this function
     * @param _dappID The dApp identifier
     * @param _discount The discount amount
     * @notice Reverts if dApp ID is zero or discount is zero
     */
    function setDappConfigDiscount(uint256 _dappID, uint256 _discount) external onlyGovOrAdmin(_dappID) {
        // require(_dappID > 0, "C3DappManager: dappID is 0");
        if (_dappID == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.DAppID);
        }
        // require(_token != address(0), "C3DappManager: token is address(0)");
        if (_discount == 0) {
            revert C3DAppManager_LengthMismatch(C3ErrorParam.DAppID, C3ErrorParam.Token);
        }

        dappConfig[_dappID].discount = _discount;
    }
}
