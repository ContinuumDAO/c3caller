// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {C3GovClient} from "../gov/C3GovClient.sol";
import {C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {IC3DAppManager} from "./IC3DAppManager.sol";

/**
 * @title C3DAppManager
 * @notice Contract for managing DApp configurations, fees, and MPC addresses in the C3 protocol.
 * This contract provides comprehensive management functionality for DApps including
 * configuration, fee management, staking pools, and MPC address management.
 *
 * Key features:
 * - DApp configuration management
 * - Fee configuration and management
 * - Fee pool management
 * - MPC address and public key management
 * - DApp lifecycle management (Active, Suspended, Dormant, Deprecated)
 * - Status-based access control and enforcement
 * - Pausable functionality for emergency stops
 *
 * @dev This contract is the central management hub for C3 DApps
 * @author @potti ContinuumDAO
 */
contract C3DAppManager is IC3DAppManager, C3GovClient, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Maximum size of the JSON metadata for each DApp
    uint256 public constant METADATA_LIMIT = 512;

    /// @notice Denominator used to calculate fee discount
    uint256 public constant DISCOUNT_DENOMINATOR = 10_000;

    /// @notice The DApp ID for the DApp manager
    uint256 public dappID;

    /// @notice Mapping of DApp ID to DApp configuration (admin, fee token, discount)
    mapping(uint256 => DAppConfig) public dappConfig;

    /// @notice Mapping of DApp address string to DApp ID
    mapping(string => uint256) public c3DAppAddr;

    /// @notice Mapping of DApp ID to DApp status (Active, Suspended, Deprecated)
    mapping(uint256 => DAppStatus) internal _dappStatus;

    /// @notice Mapping of DApp ID to reason why it was made inactive
    mapping(uint256 => string) public statusReason;

    /// @notice Mapping of fee token address to its validity status
    mapping(address => bool) public feeCurrencies;

    /// @notice Mapping of DApp ID and token address to staking pool balance
    mapping(uint256 => mapping(address => uint256)) public dappStakePool;

    /// @notice Mapping of token address and chain ID string to fee configuration (per calldata byte and per gas unit)
    mapping(address => mapping(string => FeeConfig)) public specificChainFee;

    /// @notice Mapping of token address to accumulated fees
    mapping(address => uint256) public cumulativeFees;

    /// @notice Mapping of DApp ID and MPC address to public key
    mapping(uint256 => mapping(string => string)) public mpcPubkey;

    /// @notice Mapping of DApp ID to array of MPC addresses
    mapping(uint256 => string[]) public mpcAddrs;

    /// @notice Mapping of DApp ID and MPC address to membership status
    mapping(uint256 => mapping(string => bool)) public mpcMembership;

    /// @notice Mapping of fee token to minimum deposit amount
    mapping(address => uint256) public feeMinimumDeposit;

    /// @notice Mapping of admin address to index to DApp ID
    mapping(address => mapping(uint256 => uint256)) public adminToDAppIDList;

    /// @notice Mapping of admin address to number of DApp IDs being managed
    mapping(address => uint256) public adminToDAppIDCount;

    /**
     * @notice Initializes the contract with the deployer as governance address
     * @dev The C3DAppManager DApp ID is set to zero, subsequent DApps auto-increment dappID starting from 1.
     */
    constructor() C3GovClient(msg.sender) {}

    /**
     * @notice Modifier to restrict access to governance or DApp admin
     * @param _dappID The DApp ID
     * @dev Reverts if the caller is neither governance address nor DApp admin
     */
    modifier onlyGovOrAdmin(uint256 _dappID) {
        if (msg.sender != gov && msg.sender != dappConfig[_dappID].admin) {
            revert C3DAppManager_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin);
        }
        _;
    }

    /**
     * @notice Modifier to check DApp status (Active, Suspended, Dormant, Deprecated)
     * @param _dappID The DApp ID
     * @dev Reverts if DApp is suspended, dormant or deprecated
     */
    modifier onlyActive(uint256 _dappID) {
        DAppStatus status = _parseDAppStatus(_dappID);
        if (status != DAppStatus.Active) {
            revert C3DAppManager_InactiveDApp(_dappID, status);
        }
        _;
    }

    /**
     * @notice Modifier to prevent registration of deprecated DApp IDs
     * @param _dappID The DApp ID
     * @dev Reverts if DApp ID is deprecated (_dappStatus can never be Dormant)
     */
    modifier onlyActiveOrDormant(uint256 _dappID) {
        DAppStatus status = _parseDAppStatus(_dappID);
        if (status != DAppStatus.Active && status != DAppStatus.Dormant) {
            revert C3DAppManager_InactiveDApp(_dappID, status);
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
        DAppStatus oldStatus = _dappStatus[_dappID];

        // Validate status transition
        if (!_isValidStatusTransition(oldStatus, _status)) {
            revert C3DAppManager_InvalidStatusTransition(oldStatus, _status);
        }

        _dappStatus[_dappID] = _status;
        statusReason[_dappID] = _reason;
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
        if (_from == DAppStatus.Active) {
            // Active can transition to Suspended or Deprecated
            return _to == DAppStatus.Suspended || _to == DAppStatus.Deprecated;
        } else if (_from == DAppStatus.Suspended) {
            // Suspended can transition to Active or Deprecated
            return _to == DAppStatus.Active || _to == DAppStatus.Deprecated;
        } else {
            // Deprecated cannot transition to any other status (permanent)
            return false;
        }
    }

    /**
     * @notice Register and configure a new DApp. This is how new C3Caller DApps can be registered
     * @param _feeToken The fee token address
     * @param _metadata The JSON encoded DApp name, URL, description and email for th DApp
     */
    function setDAppConfig(address _feeToken, string memory _metadata) external whenNotPaused returns (uint256) {
        uint256 _dappID = ++dappID;
        _setDAppConfig(_dappID, msg.sender, _feeToken, _metadata);

        emit SetDAppConfig(_dappID, msg.sender, _feeToken, _metadata);
        return _dappID;
    }

    /**
     * @notice Update an existing DApp configuration
     * @param _dappID The DApp ID to update
     * @param _admin The new dapp admin
     * @param _feeToken The new fee token address
     * @param _metadata The JSON encoded DApp name, URL, description and email for th DApp
     * @dev Reverts if caller is not governance or DApp admin, or if the configuration has changed in the past 30 days.
     */
    function updateDAppConfig(uint256 _dappID, address _admin, address _feeToken, string memory _metadata)
        external
        onlyGovOrAdmin(_dappID)
        onlyActiveOrDormant(_dappID)
        whenNotPaused
    {
        if (block.timestamp < dappConfig[_dappID].lastUpdated + 30 days && msg.sender != gov) {
            revert C3DAppManager_RecentlyUpdated(_dappID);
        }
        _setDAppConfig(_dappID, _admin, _feeToken, _metadata);

        emit SetDAppConfig(_dappID, _admin, _feeToken, _metadata);
    }

    /**
     * @notice Internal handler to set configuration for a new or old DApp ID
     * @param _dappID The ID of the DApp to configure
     * @param _feeToken The fee token to set
     * @param _admin The app admin to set
     * @param _metadata The JSON encoded DApp name, URL, description and email for th DApp
     * @dev Reverts if fee token is not supported or domain/email is empty
     */
    function _setDAppConfig(uint256 _dappID, address _admin, address _feeToken, string memory _metadata) internal {
        if (!feeCurrencies[_feeToken]) {
            revert C3DAppManager_InvalidFeeToken(_feeToken);
        }
        uint256 metadataLength = bytes(_metadata).length;
        if (metadataLength == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Metadata);
        }
        if (metadataLength > METADATA_LIMIT) {
            revert C3DAppManager_MetadataTooLong(metadataLength, METADATA_LIMIT);
        }

        dappConfig[_dappID] = DAppConfig({
            admin: _admin,
            feeToken: _feeToken,
            discount: dappConfig[_dappID].discount,
            lastUpdated: msg.sender == gov ? dappConfig[_dappID].lastUpdated : block.timestamp,
            metadata: _metadata
        });
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
        onlyActive(_dappID)
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
     * @dev Reverts if DApp admin is zero, addresses are empty, lengths don't match, DApp is not active,
     * or address already exists
     * @dev Only governance or DApp admin can call this function
     */
    function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey)
        external
        onlyGovOrAdmin(_dappID)
        onlyActive(_dappID)
    {
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Address);
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
        onlyActive(_dappID)
    {
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Address);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.PubKey);
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
     * @param _perByteFee Fee per byte of calldata
     * @param _perGasFee Fee per gas unit of executed transaction
     * @dev Reverts if the fee or minimum deposit is zero
     * @dev Only the governance address can call this function
     */
    function setFeeConfig(address _token, string memory _chain, uint256 _perByteFee, uint256 _perGasFee)
        external
        onlyGov
    {
        if (_perByteFee == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }
        if (_perGasFee == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerGas);
        }

        feeCurrencies[_token] = true;
        specificChainFee[_token][_chain].perByte = _perByteFee;
        specificChainFee[_token][_chain].perGas = _perGasFee;

        emit SetFeeConfig(_token, _chain, _perByteFee, _perGasFee);
    }

    /**
     * @notice Set the minimum deposit amount for a fee token
     * @param _feeToken The fee token to set the minimum deposit for
     * @param _feeMinimumDeposit The minimum deposit that is permissible for a fee token
     * @dev Reverts if caller is not gov, if fee token is not supported or if minimumDeposit is zero
     */
    function setFeeMinimumDeposit(address _feeToken, uint256 _feeMinimumDeposit) external onlyGov {
        if (_feeMinimumDeposit == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.MinimumDeposit);
        }
        if (!feeCurrencies[_feeToken]) {
            revert C3DAppManager_InvalidFeeToken(_feeToken);
        }
        feeMinimumDeposit[_feeToken] = _feeMinimumDeposit;
        emit SetFeeMinimumDeposit(_feeToken, _feeMinimumDeposit);
    }

    /**
     * @notice Remove fee configuration for a fee and network
     * @param _token The fee token address
     * @dev Only the governance address can call this function
     * @dev The value of specificChainFee may still be required to charge fees that were due before the removal
     */
    function removeFeeConfig(address _token) external onlyGov {
        delete feeCurrencies[_token];
        delete feeMinimumDeposit[_token];
        emit DeleteFeeConfig(_token);
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
        nonZeroDAppID(_dappID)
        onlyActive(_dappID)
        whenNotPaused
    {
        uint256 minimum = feeMinimumDeposit[_token];
        if (_amount < minimum) {
            revert C3DAppManager_BelowMinimumDeposit(_amount, minimum);
        }

        dappStakePool[_dappID][_token] += _amount;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(_dappID, _token, _amount, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Withdraw all tokens from a DApp's staking pool to the DApp admin
     * @param _dappID The DApp ID
     * @param _token The token address
     * @dev Reverts if DApp ID is zero, amount is zero, or insufficient balance
     * @dev Only governance can call this function
     */
    function withdraw(uint256 _dappID, address _token) external onlyGov nonZeroDAppID(_dappID) whenNotPaused {
        uint256 amount = dappStakePool[_dappID][_token];
        if (amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Fee);
        }

        dappStakePool[_dappID][_token] = 0;

        IERC20(_token).safeTransfer(dappConfig[_dappID].admin, amount);

        emit Withdraw(_dappID, _token, amount);
    }

    /**
     * @notice Charge fees from a DApp's staking pool
     * @param _dappID The DApp ID
     * @param _token The token address
     * @param _sizeBytes K
     * @param _sizeGas K
     * @param _chain The target network to charge for
     * @dev Reverts if DApp ID is zero, bill is zero, or insufficient balance
     * @dev Only governance or DApp admin can call this function
     */
    function charging(uint256 _dappID, address _token, uint256 _sizeBytes, uint256 _sizeGas, string memory _chain)
        external
        onlyGov
        nonZeroDAppID(_dappID)
        whenNotPaused
    {
        FeeConfig memory feeConfig = specificChainFee[_token][_chain];
        uint256 bill = (feeConfig.perByte * _sizeBytes) + (feeConfig.perGas * _sizeGas);

        if (bill == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Fee);
        }

        if (dappStakePool[_dappID][_token] < bill) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        // NOTE: if the gross bill << 10_000, then discount is forfeited due to integer division (as it would have been negligible anyway)
        uint256 discount = bill * dappConfig[_dappID].discount / DISCOUNT_DENOMINATOR;

        dappStakePool[_dappID][_token] -= (bill - discount);
        cumulativeFees[_token] += (bill - discount);
        IERC20(_token).safeTransfer(gov, (bill - discount));

        emit Charging(_dappID, _token, bill, discount, dappStakePool[_dappID][_token]);
    }

    /**
     * @notice Set DApp configuration discount
     * @param _dappID The DApp ID
     * @param _discount The discount coefficient between 0 (no discount) and 10k (100% discount)
     * @dev Reverts if DApp ID is zero, discount is zero, or DApp is not active
     * @dev Only governance or DApp admin can call this function
     */
    function setDAppFeeDiscount(uint256 _dappID, uint256 _discount) external onlyGov nonZeroDAppID(_dappID) {
        if (_discount > DISCOUNT_DENOMINATOR) {
            revert C3DAppManager_DiscountAboveMax(_discount, DISCOUNT_DENOMINATOR);
        }
        dappConfig[_dappID].discount = _discount;
        emit SetDAppFeeDiscount(_dappID, _discount);
    }

    /**
     * @notice Get all MPC addresses that have been added for a given DApp
     * @param _dappID The DApp ID
     * @return Array of MPC addresses
     * @dev Reverts if DApp ID is zero
     */
    function getAllMpcAddrs(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (string[] memory) {
        return mpcAddrs[_dappID];
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
     * @notice Check DApp status
     * @param _dappID The dapp ID in question
     * @return Active, Dormant, Suspended or Deprecated
     * @dev Calling _parseDAppStatus to check for dormant status
     */
    function dappStatus(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (DAppStatus) {
        return _parseDAppStatus(_dappID);
    }

    /**
     * @notice Check the status of the DApp (Active, Suspended, Dormant, Deprecated)
     * @param _dappID The DApp ID in question
     * @return Dormant if the fee token is no longer supported, otherwise current status
     */
    function _parseDAppStatus(uint256 _dappID) internal view returns (DAppStatus) {
        DAppStatus status = _dappStatus[_dappID];
        if (status == DAppStatus.Active && !feeCurrencies[dappConfig[_dappID].feeToken]) {
            return DAppStatus.Dormant;
        } else {
            return status;
        }
    }
}
