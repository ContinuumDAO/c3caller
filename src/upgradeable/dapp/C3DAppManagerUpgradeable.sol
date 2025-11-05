// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IC3DAppManagerUpgradeable} from "./IC3DAppManagerUpgradeable.sol";
import {C3ErrorParam} from "../../utils/C3CallerUtils.sol";
import {C3GovClientUpgradeable} from "../gov/C3GovClientUpgradeable.sol";

/**
 * @title C3DAppManagerUpgradeable
 * @notice Upgradeable contract for managing DApp configurations, fees, and MPC addresses in the C3 protocol.
 * This contract provides comprehensive management functionality for DApps including
 * configuration, fee management, staking pools, MPC address management, with upgradeable capabilities.
 *
 * Key features:
 * - DApp configuration management
 * - Fee configuration and management
 * - Staking pool management
 * - MPC address and public key management
 * - Blacklist functionality
 * - DApp lifecycle management (Active, Suspended, Deprecated)
 * - Status-based access control and enforcement
 * - Pausable and upgradeable functionality for emergency stops
 *
 * @dev This contract is the central management hub for upgradeable C3 DApps
 * @author @potti ContinuumDAO
 */
contract C3DAppManagerUpgradeable is
    IC3DAppManagerUpgradeable,
    C3GovClientUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using Strings for *;
    using SafeERC20 for IERC20;

    /// @notice The DApp ID for the DApp manager
    uint256 public dappID;

    /// @notice Mapping of DApp ID to DApp configuration (admin, fee token, discount)
    mapping(uint256 => DAppConfig) private dappConfig;

    /// @notice Mapping of DApp address string to DApp ID
    mapping(string => uint256) public c3DAppAddr;

    /// @notice Mapping of DApp ID to blacklist status
    mapping(uint256 => bool) public appBlacklist;

    /// @notice Mapping of DApp ID to DApp status (Active, Suspended, Deprecated)
    mapping(uint256 => DAppStatus) public dappStatus;

    /// @notice Mapping of fee token address to fee per byte
    mapping(address => uint256) public feeCurrencies;

    /// @notice Mapping of DApp ID and token address to staking pool balance
    mapping(uint256 => mapping(address => uint256)) public dappStakePool;

    /// @notice Mapping of chain ID string and token address to fee, to inspect other networks' fees
    mapping(string => mapping(address => uint256)) public speChainFees;

    /// @notice Mapping of token address to accumulated fees
    mapping(address => uint256) private fees;

    /// @notice Mapping of DApp ID and MPC address to public key
    mapping(uint256 => mapping(string => string)) public mpcPubkey;

    /// @notice Mapping of DApp ID to array of MPC addresses
    mapping(uint256 => string[]) public mpcAddrs;

    /// @notice Mapping of DApp ID and MPC address to membership status
    mapping(uint256 => mapping(string => bool)) public mpcMembership;

    /**
     * @notice Initializer for the upgradeable C3DAppManager contract
     * @dev This function can only be called once during deployment
     */
    function initialize() public initializer {
        __C3GovClient_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
        dappID = 0;
    }

    /**
     * @notice Disable initializers
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Modifier to restrict access to governance or DApp admin
     * @param _dappID The DApp ID
     * @dev Reverts if the caller is neither governance address nor DApp admin
     */
    modifier onlyGovOrAdmin(uint256 _dappID) {
        if (msg.sender != gov() && msg.sender != dappConfig[_dappID].appAdmin) {
            revert C3DAppManager_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin);
        }
        _;
    }

    /**
     * @notice Modifier to check DApp status (Active, Suspended, Deprecated)
     * @param _dappID The DApp ID
     * @dev Reverts if DApp is suspended or deprecated
     */
    modifier onlyActiveDApp(uint256 _dappID) {
        DAppStatus status = dappStatus[_dappID];
        if (status == DAppStatus.Suspended) {
            revert C3DAppManager_DAppSuspended(_dappID);
        }
        if (status == DAppStatus.Deprecated) {
            revert C3DAppManager_DAppDeprecated(_dappID);
        }
        _;
    }

    /**
     * @notice Modifier to prevent registration of deprecated DApp IDs
     * @param _dappID The DApp ID
     * @dev Reverts if DApp ID is deprecated
     */
    modifier notDeprecated(uint256 _dappID) {
        if (dappStatus[_dappID] == DAppStatus.Deprecated) {
            revert C3DAppManager_DAppDeprecated(_dappID);
        }
        _;
    }

    /**
     * @notice Modifier to ensure DApp ID is non-zero
     * @param _dappID The DApp ID
     * @dev Reverts if DApp ID is zero
     */
    modifier nonZeroDAppID(uint256 _dappID) {
        if (_dappID == 0) {
            revert C3DAppManager_ZeroDAppID();
        }
        _;
    }

    /**
     * @notice Pause the contract (governance only)
     * @dev Only the governance address can call this function
     */
    function pause() public onlyGov {
        _pause();
    }

    /**
     * @notice Unpause the contract (governance only)
     * @dev Only the governance address can call this function
     */
    function unpause() public onlyGov {
        _unpause();
    }

    /**
     * @notice Set blacklist status for a DApp (governance only)
     * @param _dappID The DApp ID
     * @param _flag The blacklist flag (true or false)
     * @dev Reverts if DApp ID is zero. Only the governance address can call this function
     */
    function setBlacklists(uint256 _dappID, bool _flag) external onlyGov nonZeroDAppID(_dappID) {
        appBlacklist[_dappID] = _flag;
        emit SetBlacklists(_dappID, _flag);
    }

    /**
     * @notice Set DApp status (Active, Suspended, Deprecated)
     * @param _dappID The DApp ID
     * @param _status The new status
     * @param _reason The reason for the status change
     * @dev Reverts if the status transition is invalid or DApp ID is zero
     * @dev Only the governance address can call this function
     */
    function setDAppStatus(uint256 _dappID, DAppStatus _status, string memory _reason)
        external
        onlyGov
        nonZeroDAppID(_dappID)
    {
        DAppStatus oldStatus = dappStatus[_dappID];

        // Validate status transition
        if (!_isValidStatusTransition(oldStatus, _status)) {
            revert C3DAppManager_InvalidStatusTransition(oldStatus, _status);
        }

        dappStatus[_dappID] = _status;
        emit DAppStatusChanged(_dappID, oldStatus, _status, _reason);
    }

    /**
     * @notice Internal function to validate status transitions
     * @param _from The current status
     * @param _to The target status
     * @return True if the transition is valid
     * @dev Deprecated DApps cannot undergo status change - deprecation is permanent
     */
    function _isValidStatusTransition(DAppStatus _from, DAppStatus _to) internal pure returns (bool) {
        // Active can transition to Suspended or Deprecated
        if (_from == DAppStatus.Active) {
            return _to == DAppStatus.Suspended || _to == DAppStatus.Deprecated;
        }

        // Suspended can transition to Active or Deprecated
        if (_from == DAppStatus.Suspended) {
            return _to == DAppStatus.Active || _to == DAppStatus.Deprecated;
        }

        // Deprecated cannot transition to any other status (permanent)
        if (_from == DAppStatus.Deprecated) {
            return false;
        }

        return false;
    }

    /**
     * @notice Set DApp configuration. This is how new C3Caller DApps can be registered.
     * @param _dappID The DApp ID
     * @param _appAdmin The DApp admin address
     * @param _feeToken The fee token address
     * @param _appDomain The DApp domain
     * @param _email The DApp email
     * @dev Reverts if fee token is zero, domain/email is empty, DApp ID is zero, or DApp ID is deprecated
     * @dev Only the governance address can call this function
     */
    function setDAppConfig(
        uint256 _dappID,
        address _appAdmin,
        address _feeToken,
        string memory _appDomain,
        string memory _email
    ) external onlyGov nonZeroDAppID(_dappID) notDeprecated(_dappID) {
        if (_feeToken == address(0)) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }
        if (bytes(_appDomain).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.AppDomain);
        }
        if (bytes(_email).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Email);
        }

        dappConfig[_dappID] = DAppConfig({id: _dappID, appAdmin: _appAdmin, feeToken: _feeToken, discount: 0});

        emit SetDAppConfig(_dappID, _appAdmin, _feeToken, _appDomain, _email);
    }

    /**
     * @notice Set DApp addresses
     * @notice This is network-agnostic, therefore all deployed instances using `_dappID` should be included.
     * @param _dappID The DApp ID
     * @param _addresses Array of DApp addresses
     * @dev Reverts if DApp ID is zero or DApp is not active
     * @dev Only governance or DApp admin can call this function
     */
    function setDAppAddr(uint256 _dappID, string[] memory _addresses)
        external
        onlyGovOrAdmin(_dappID)
        nonZeroDAppID(_dappID)
        onlyActiveDApp(_dappID)
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            c3DAppAddr[_addresses[i]] = _dappID;
        }
        emit SetDAppAddr(_dappID, _addresses);
    }

    /**
     * @notice Add MPC address and its corresponding public key to a given DApp
     * @param _dappID The DApp ID
     * @param _addr The MPC address (EVM 20-byte address)
     * @param _pubkey The MPC public key (32-byte MPC node public key)
     * @dev Reverts if DApp ID is zero, DApp admin is zero, addresses are empty, lengths don't match, DApp is not
     * active, or address already exists
     * @dev Only governance or DApp admin can call this function
     */
    function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey)
        external
        onlyGovOrAdmin(_dappID)
        nonZeroDAppID(_dappID)
        onlyActiveDApp(_dappID)
    {
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
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

        // Check if MPC address already exists
        if (mpcMembership[_dappID][_addr]) {
            revert C3DAppManager_MpcAddressExists(_addr);
        }

        mpcPubkey[_dappID][_addr] = _pubkey;
        mpcAddrs[_dappID].push(_addr);
        mpcMembership[_dappID][_addr] = true;

        emit AddMpcAddr(_dappID, _addr, _pubkey);
    }

    /**
     * @notice Delete MPC address and its corresponding public key for a given DApp
     * @param _dappID The DApp ID
     * @param _addr The MPC address to delete
     * @param _pubkey The MPC public key to delete
     * @dev Reverts if DApp ID is zero, DApp admin is zero, addresses are empty, DApp is not active,
     * or address not found
     * @dev Only governance or DApp admin can call this function
     */
    function delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey)
        external
        onlyGovOrAdmin(_dappID)
        nonZeroDAppID(_dappID)
        onlyActiveDApp(_dappID)
    {
        if (dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }

        // Check if MPC address exists
        if (!mpcMembership[_dappID][_addr]) {
            revert C3DAppManager_MpcAddressNotFound(_addr);
        }

        delete mpcPubkey[_dappID][_addr];
        mpcMembership[_dappID][_addr] = false;

        // Remove from array using swap-and-pop technique
        string[] storage addrs = mpcAddrs[_dappID];
        for (uint256 i = 0; i < addrs.length; i++) {
            if (keccak256(bytes(addrs[i])) == keccak256(bytes(_addr))) {
                // Swap with last element and pop
                addrs[i] = addrs[addrs.length - 1];
                addrs.pop();
                break;
            }
        }

        emit DelMpcAddr(_dappID, _addr, _pubkey);
    }

    /**
     * @notice Set fee configuration for a fee token and network
     * @param _token The fee token address
     * @param _chain The chain ID
     * @param _callPerByteFee The fee per byte
     * @dev Reverts if the fee is zero
     * @dev Only the governance address can call this function
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
     * @param _dappID The DApp ID
     * @param _token The token address
     * @param _amount The amount to deposit
     * @dev Reverts if DApp ID is zero, amount is zero, or DApp is not active
     */
    function deposit(uint256 _dappID, address _token, uint256 _amount)
        external
        whenNotPaused
        nonZeroDAppID(_dappID)
        onlyActiveDApp(_dappID)
    {
        if (_amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        dappStakePool[_dappID][_token] += _amount;

        emit Deposit(_dappID, _token, _amount, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Withdraw tokens from a DApp's staking pool
     * @param _dappID The DApp ID
     * @param _token The token address
     * @param _amount The amount to withdraw
     * @dev Reverts if DApp ID is zero, amount is zero, or insufficient balance
     * @dev Only governance or DApp admin can call this function
     */
    function withdraw(uint256 _dappID, address _token, uint256 _amount)
        external
        onlyGovOrAdmin(_dappID)
        nonZeroDAppID(_dappID)
        whenNotPaused
    {
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
     * @notice Charge fees from a DApp's staking pool
     * @param _dappID The DApp ID
     * @param _token The token address
     * @param _size The size of the cumulative cross-chain messages to charge for
     * @param _chain The target network to charge for
     * @dev Reverts if DApp ID is zero, bill is zero, or insufficient balance
     * @dev Only governance or DApp admin can call this function
     */
    function charging(uint256 _dappID, address _token, uint256 _size, string memory _chain)
        external
        onlyGovOrAdmin(_dappID)
        nonZeroDAppID(_dappID)
        whenNotPaused
    {
        // ISSUE: #3
        uint256 feePerByte = speChainFees[_token][_chain];
        uint256 bill = feePerByte * _size;

        if (bill == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        if (dappStakePool[_dappID][_token] < bill) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        dappStakePool[_dappID][_token] -= bill;

        // ISSUE: #2
        fees[_token] += bill;
        IERC20(_token).safeTransfer(gov, bill);

        emit Charging(_dappID, _token, bill, bill, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Get DApp configuration (admin, fee token, discount)
     * @param _dappID The DApp ID
     * @return The DApp configuration
     * @dev Reverts if DApp ID is zero
     */
    function getDAppConfig(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (DAppConfig memory) {
        return dappConfig[_dappID];
    }

    /**
     * @notice Get DApp status (Active, Suspended, Deprecated)
     * @param _dappID The DApp ID
     * @return The DApp status
     * @dev Reverts if DApp ID is zero
     */
    function getDAppStatus(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (DAppStatus) {
        return dappStatus[_dappID];
    }

    /**
     * @notice Get MPC addresses that have been added for a given DApp
     * @param _dappID The DApp ID
     * @return Array of MPC addresses
     * @dev Reverts if DApp ID is zero
     */
    function getMpcAddrs(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (string[] memory) {
        return mpcAddrs[_dappID];
    }

    /**
     * @notice Get MPC public key for a DApp and address
     * @param _dappID The DApp ID
     * @param _addr The MPC address
     * @return The MPC public key
     * @dev Reverts if DApp ID is zero
     */
    function getMpcPubkey(uint256 _dappID, string memory _addr)
        external
        view
        nonZeroDAppID(_dappID)
        returns (string memory)
    {
        return mpcPubkey[_dappID][_addr];
    }

    /**
     * @notice Check if MPC address is a member of a DApp
     * @param _dappID The DApp ID
     * @param _addr The MPC address
     * @return True if the address is a member
     * @dev Reverts if DApp ID is zero
     */
    function isMpcMember(uint256 _dappID, string memory _addr) external view nonZeroDAppID(_dappID) returns (bool) {
        return mpcMembership[_dappID][_addr];
    }

    /**
     * @notice Get the number of MPC addresses for a DApp
     * @param _dappID The DApp ID
     * @return The number of MPC addresses
     * @dev Reverts if DApp ID is zero
     */
    function getMpcCount(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (uint256) {
        return mpcAddrs[_dappID].length;
    }

    /**
     * @notice Get fee currency for a token (fee per byte)
     * @param _token The token address
     * @return The fee per byte for the token
     */
    function getFeeCurrency(address _token) external view returns (uint256) {
        return feeCurrencies[_token];
    }

    /**
     * @notice Get specific network's fee for a token
     * @param _chain The chain ID
     * @param _token The fee token address
     * @return The fee per byte of the fee token on the specific network
     */
    function getSpeChainFee(string memory _chain, address _token) external view returns (uint256) {
        return speChainFees[_chain][_token];
    }

    /**
     * @notice Get staking pool balance of a specific DApp
     * @param _dappID The DApp ID
     * @param _token The token address
     * @return The staking pool balance
     * @dev Reverts if DApp ID is zero
     */
    function getDAppStakePool(uint256 _dappID, address _token) external view nonZeroDAppID(_dappID) returns (uint256) {
        return dappStakePool[_dappID][_token];
    }

    /**
     * @notice Get accumulated fees for a token
     * @param _token The fee token address
     * @return The accumulated fees
     */
    function getFee(address _token) external view returns (uint256) {
        return fees[_token];
    }

    /**
     * @notice Set accumulated fees for a token
     * @param _token The fee token address
     * @param _fee The fee amount
     * @dev Only the governance address can call this function
     */
    // function setFee(address _token, uint256 _fee) external onlyGov {
    //     fees[_token] = _fee;
    // }

    /**
     * @notice Set the DApp ID for this manager (governance only)
     * @dev Only the governance address can call this function
     * @param _dappID The DApp ID
     */
    function setDAppID(uint256 _dappID) external onlyGov {
        dappID = _dappID;
    }

    /**
     * @notice Set DApp configuration discount
     * @param _dappID The DApp ID
     * @param _discount The discount amount
     * @dev Reverts if DApp ID is zero, discount is zero, or DApp is not active
     * @dev Only governance or DApp admin can call this function
     */
    function setDAppConfigDiscount(uint256 _dappID, uint256 _discount)
        external
        onlyGovOrAdmin(_dappID)
        nonZeroDAppID(_dappID)
        onlyActiveDApp(_dappID)
    {
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
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyGov {}
}
