// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IC3DAppManagerUpgradeable} from "./IC3DAppManagerUpgradeable.sol";
import {IC3Caller} from "../../IC3Caller.sol";
import {C3GovClientUpgradeable} from "../gov/C3GovClientUpgradeable.sol";
import {C3ErrorParam} from "../../utils/C3CallerUtils.sol";

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
 * @author @potti, @patrickcure, @selqui ContinuumDAO
 */
contract C3DAppManagerUpgradeable is IC3DAppManagerUpgradeable, C3GovClientUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Maximum size of the JSON metadata for each DApp
    uint256 public constant METADATA_LIMIT = 512;

    /// @notice Maximum size of the DApp key
    uint256 public constant DAPP_KEY_LIMIT = 64;

    /// @notice Denominator used to calculate fee discount
    uint256 public constant DISCOUNT_DENOMINATOR = 10_000;

    /// @notice The latest DApp ID that was registered
    uint256 public dappIDRegistry;

    /// @notice Mapping of DApp ID to DApp configuration (admin, fee token, discount)
    mapping(uint256 => DAppConfig) public dappConfig;

    /// @notice Mapping of DApp ID and token address to staking pool balance
    mapping(uint256 => mapping(address => uint256)) public dappStakePool;

    /// @notice Mapping of DApp address to its DApp ID
    mapping(address => uint256) public dappAddrID;

    /// @notice Mapping of DApp ID to C3CallerDApp implementation, which may call C3Caller.c3call
    mapping(uint256 => address[]) public dappAddrs;

    /// @notice Mapping of DApp ID to array of MPC addresses
    mapping(uint256 => address[]) public dappMPCAddrs;

    /// @notice Mapping of DApp ID and MPC address to MPC group public key
    mapping(uint256 => mapping(address => string)) public dappMPCPubkey;

    /// @notice Mapping of DApp ID and MPC address to membership status
    mapping(uint256 => mapping(address => bool)) public dappMPCMembership;

    /// @notice Mapping of admin address to index to DApp ID
    mapping(address => mapping(uint256 => uint256)) public adminToDAppIDList;

    /// @notice Mapping of admin address to number of DApp IDs being managed
    mapping(address => uint256) public adminToDAppIDCount;

    /// @notice Mapping of fee token address to its validity status
    mapping(address => bool) public feeCurrencies;

    /// @notice Mapping of fee token to minimum deposit amount
    mapping(address => uint256) public feeMinimumDeposit;

    /// @notice Mapping of fee token address to payload fee per byte
    mapping(address => uint256) public payloadPerByteFee;

    /// @notice Mapping of fee token address to gas fee per ether
    mapping(address => uint256) public gasPerEtherFee;

    /// @notice Mapping of token address to accumulated fees
    mapping(address => uint256) public cumulativeFees;

    /// @notice Mapping of creator's address to their list of DApp keys
    mapping(address => string[]) public creatorDAppKeys;

    /// @notice Mapping of DApp key to its creator's address
    mapping(string => address) public dappKeyCreator;

    /// @notice Mapping of DApp ID to reason why it was made inactive
    mapping(uint256 => string) public statusReason;

    /// @notice Mapping of DApp ID to DApp status (Active, Suspended, Deprecated)
    mapping(uint256 => DAppStatus) internal _dappStatus;

    /**
     * @notice Modifier to restrict access to governance or DApp admin
     * @param _dappID The DApp ID
     * @dev Reverts if the caller is neither governance address nor DApp admin
     */
    modifier onlyGovOrAdmin(uint256 _dappID) {
        if (msg.sender != gov() && msg.sender != dappConfig[_dappID].admin) {
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
     * @notice Modifier to prevent operations using a non-existent DApp ID
     * @param _dappID The DApp ID to check
     */
    modifier dappIDExists(uint256 _dappID) {
        if (!_checkDAppIDExists(_dappID)) {
            revert C3DAppManager_InvalidDAppID(_dappID);
        }
        _;
    }

    /**
     * @notice Initializer for the upgradeable C3DAppManager contract, with the deployer as governance
     * @dev This function can only be called once during deployment
     */
    function initialize() public initializer {
        __C3GovClient_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Disable initializers
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Register and configure a new DApp. This is how new C3Caller DApps can be registered
     * @param _dappKey The user-defined DApp identifier in the form of "v1.protocolname.contractname"
     * @param _feeToken The fee token address
     * @param _metadata The JSON encoded DApp name, URL, description and email for the DApp
     * @dev The DApp ID will be deterministic for an admin who calls this on other chains with the same DApp key
     */
    function initDAppConfig(
        string memory _dappKey,
        address _feeToken,
        string memory _metadata
    ) external whenNotPaused returns (uint256) {
        dappIDRegistry++;
        uint256 _dappID = _deriveDAppID(msg.sender, _dappKey);

        uint256 dappKeyLength = bytes(_dappKey).length;
        if (dappKeyLength == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.DAppKey);
        }
        if (dappKeyLength > DAPP_KEY_LIMIT) {
            revert C3DAppManager_StringTooLong(dappKeyLength, DAPP_KEY_LIMIT);
        }
        if (_checkDAppIDExists(_dappID)) {
            revert C3DAppManager_InvalidDAppID(_dappID);
        }

        creatorDAppKeys[msg.sender].push(_dappKey);
        dappKeyCreator[_dappKey] = msg.sender;

        _setDAppConfig(_dappID, msg.sender, _feeToken, _metadata);
        _deposit(_dappID, _feeToken, feeMinimumDeposit[_feeToken]);

        emit InitDAppConfig(_dappID, _dappKey, msg.sender, _feeToken, _metadata);
        return _dappID;
    }

    /**
     * @notice Update an existing DApp configuration
     * @param _dappID The DApp ID to update
     * @param _admin The new dapp admin
     * @param _feeToken The new fee token address
     * @param _metadata The JSON encoded DApp name, URL, description and email for the DApp
     * @dev Reverts if caller is not governance or DApp admin, or if the configuration has changed in the past 30 days.
     */
    function updateDAppConfig(uint256 _dappID, address _admin, address _feeToken, string memory _metadata)
        external
        dappIDExists(_dappID)
        onlyGovOrAdmin(_dappID)
        onlyActiveOrDormant(_dappID)
        whenNotPaused
    {
        if (block.timestamp < dappConfig[_dappID].lastUpdated + 30 days && msg.sender != gov()) {
            revert C3DAppManager_RecentlyUpdated(_dappID);
        }
        _setDAppConfig(_dappID, _admin, _feeToken, _metadata);

        emit UpdateDAppConfig(_dappID, _admin, _feeToken, _metadata);
    }

    /**
     * @notice Set C3CallerDApp implementation address(es), which may call C3Caller.c3call
     * @param _dappID The DApp ID
     * @param _addr DApp address to add/remove
     * @param _status Whether to add or remove the DApp address
     * @dev Reverts if DApp ID is zero or DApp is not active
     * @dev Only governance or DApp admin can call this function
     */
    function setDAppAddr(uint256 _dappID, address _addr, bool _status)
        external
        dappIDExists(_dappID)
        onlyGovOrAdmin(_dappID)
        onlyActive(_dappID)
        whenNotPaused
    {
        if (_status && dappAddrID[_addr] == 0) {
            dappAddrID[_addr] = _dappID;
            dappAddrs[_dappID].push(_addr);
        } else if (!_status && dappAddrID[_addr] != 0) {
            delete dappAddrID[_addr];
            uint256 dappIDCount = dappAddrs[_dappID].length;
            for (uint256 i = 0; i < dappIDCount; i++) {
                if (dappAddrs[_dappID][i] == _addr) {
                    dappAddrs[_dappID][i] = dappAddrs[_dappID][dappIDCount - 1];
                    dappAddrs[_dappID].pop();
                    break;
                }
            }
        } else {
            revert C3DAppManager_InvalidDAppAddr(_addr);
        }

        emit SetDAppAddr(_dappID, _addr, _status);
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
    function addDAppMPCAddr(uint256 _dappID, address _addr, string memory _pubkey)
        external
        dappIDExists(_dappID)
        onlyGovOrAdmin(_dappID)
        onlyActive(_dappID)
        whenNotPaused
    {
        if (!IC3Caller(c3caller()).isMPCAddr(_addr)) {
            revert C3DAppManager_InvalidMPCAddress(_addr);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.PubKey);
        }

        // Check if MPC address already exists
        if (dappMPCMembership[_dappID][_addr]) {
            revert C3DAppManager_MPCAddressExists(_addr);
        }

        dappMPCPubkey[_dappID][_addr] = _pubkey;
        dappMPCAddrs[_dappID].push(_addr);
        dappMPCMembership[_dappID][_addr] = true;

        emit AddMPCAddr(_dappID, _addr, _pubkey);
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
    function delDAppMPCAddr(uint256 _dappID, address _addr, string memory _pubkey)
        external
        dappIDExists(_dappID)
        onlyGovOrAdmin(_dappID)
        onlyActive(_dappID)
        whenNotPaused
    {
        if (_addr == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Address);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.PubKey);
        }

        // Check if MPC address exists
        if (!dappMPCMembership[_dappID][_addr]) {
            revert C3DAppManager_MPCAddressNotFound(_addr);
        }

        delete dappMPCPubkey[_dappID][_addr];
        dappMPCMembership[_dappID][_addr] = false;

        // Remove from array using swap-and-pop technique
        address[] storage addrs = dappMPCAddrs[_dappID];
        for (uint256 i = 0; i < addrs.length; i++) {
            if (addrs[i] == _addr) {
                // Swap with last element and pop
                addrs[i] = addrs[addrs.length - 1];
                addrs.pop();
                break;
            }
        }

        emit DelMPCAddr(_dappID, _addr, _pubkey);
    }

    /**
     * @notice Deposit tokens to a DApp's staking pool
     * @param _dappID The DApp ID
     * @param _feeToken The token address
     * @param _amount The amount to deposit
     * @dev Reverts if DApp ID does not exist or DApp is not active
     */
    function deposit(
        uint256 _dappID,
        address _feeToken,
        uint256 _amount
    ) external dappIDExists(_dappID) onlyActive(_dappID) whenNotPaused {
        _deposit(_dappID, _feeToken, _amount);
    }

    /**
     * @notice Withdraw all tokens from a DApp's staking pool to the DApp admin
     * @param _dappID The DApp ID
     * @param _feeToken The token address
     * @dev Reverts if DApp ID is zero, amount is zero, or insufficient balance
     * @dev Only governance or DApp admin can call this function
     */
    function withdraw(
        uint256 _dappID,
        address _feeToken
    ) external dappIDExists(_dappID) onlyGovOrAdmin(_dappID) whenNotPaused {
        uint256 amount = dappStakePool[_dappID][_feeToken];
        if (feeCurrencies[_feeToken]) {
            uint256 minimumRemainder = feeMinimumDeposit[_feeToken];
            unchecked {
                if (amount >= minimumRemainder) {
                    amount -= minimumRemainder;
                } else {
                    revert C3DAppManager_BelowMinimumDeposit(amount, minimumRemainder);
                }
            }
        }

        if (amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Fee);
        }

        dappStakePool[_dappID][_feeToken] -= amount;

        address admin = dappConfig[_dappID].admin;
        uint256 adminBalInitial = IERC20(_feeToken).balanceOf(admin);
        IERC20(_feeToken).safeTransfer(admin, amount);
        uint256 adminBalFinal = IERC20(_feeToken).balanceOf(admin);
        assert(adminBalFinal == adminBalInitial + amount);

        emit Withdraw(_dappID, _feeToken, amount);
    }

    /**
     * @notice Charge fees from a DApp's staking pool
     * @param _dappID The DApp ID to charge for
     * @param _payloadSizeBytes The payload calldata size
     * @dev Reverts if DApp ID does not exist
     * @dev Only C3Caller can call this function (via c3call)
     */
    function chargePayload(
        uint256 _dappID,
        uint256 _payloadSizeBytes
    ) external dappIDExists(_dappID) onlyC3Caller onlyActive(_dappID) whenNotPaused {
        DAppConfig memory _dappConfig = dappConfig[_dappID];
        uint256 bill = payloadPerByteFee[_dappConfig.feeToken] * _payloadSizeBytes;

        if (bill == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Fee);
        }
        uint256 discount = bill * _dappConfig.discount / DISCOUNT_DENOMINATOR;
        if (dappStakePool[_dappID][_dappConfig.feeToken] < (bill - discount)) {
            revert C3DAppManager_InsufficientBalance(dappStakePool[_dappID][_dappConfig.feeToken], bill - discount);
        }
        dappStakePool[_dappID][_dappConfig.feeToken] -= (bill - discount);
        cumulativeFees[_dappConfig.feeToken] += (bill - discount);

        emit ChargePayload(_dappID, _dappConfig.feeToken, bill, discount, dappStakePool[_dappID][_dappConfig.feeToken]);
    }

    /**
     * @notice Charge gas fees from a DApp's staking pool
     * @param _dappID The DApp ID to charge for
     * @param _gasSizeEther The gas ether cost
     * @dev Reverts if DApp ID does not exist, the bill amount is zero or the DApp does not have sufficient funds
     * @dev Only C3Caller can call this function (via execute or c3Fallback)
     */
    function chargeGas(
        uint256 _dappID,
        uint256 _gasSizeEther
    ) external dappIDExists(_dappID) onlyC3Caller whenNotPaused {
        DAppConfig memory _dappConfig = dappConfig[_dappID];
        uint256 bill = gasPerEtherFee[_dappConfig.feeToken] * _gasSizeEther / 1 ether;

        if (bill == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Fee);
        }
        if (dappStakePool[_dappID][_dappConfig.feeToken] < bill) {
            revert C3DAppManager_InsufficientBalance(dappStakePool[_dappID][_dappConfig.feeToken], bill);
        }
        dappStakePool[_dappID][_dappConfig.feeToken] -= bill;
        cumulativeFees[_dappConfig.feeToken] += bill;

        emit ChargeGas(_dappID, _dappConfig.feeToken, bill, dappStakePool[_dappID][_dappConfig.feeToken]);
    }

    /**
     * @notice Transfer accumulated fees from C3Caller bills to treasury
     * @param _feeToken The fee token to collect
     * @dev Anyone can call this, no governance vote required
     */
    function collect(address _feeToken) external {
        uint256 total = cumulativeFees[_feeToken];
        if (total == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Fee);
        }
        cumulativeFees[_feeToken] = 0;

        uint256 govBalInitial = IERC20(_feeToken).balanceOf(gov());
        IERC20(_feeToken).safeTransfer(gov(), total);
        uint256 govBalFinal = IERC20(_feeToken).balanceOf(gov());
        assert(govBalFinal == govBalInitial + total);
        emit Collect(_feeToken, total);
    }

    /**
     * @notice Set fee configuration for a fee token and network
     * @param _feeToken The fee token address
     * @param _payloadPerByteFee Fee per byte of calldata payload in C3Caller.c3call
     * @param _gasPerEtherFee Fee per ether spent in gas during C3Caller.execute
     * @dev Reverts if the fee or minimum deposit is zero
     * @dev Only the governance address can call this function
     */
    function setFeeConfig(address _feeToken, uint256 _payloadPerByteFee, uint256 _gasPerEtherFee)
        external
        onlyGov
    {
        if (_feeToken == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Token);
        }
        if (_payloadPerByteFee == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.PerByteFee);
        }
        if (_gasPerEtherFee == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.PerGasFee);
        }

        feeCurrencies[_feeToken] = true;
        payloadPerByteFee[_feeToken] = _payloadPerByteFee;
        gasPerEtherFee[_feeToken] = _gasPerEtherFee;

        emit SetFeeConfig(_feeToken, _payloadPerByteFee, _gasPerEtherFee);
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
     * @param _feeToken The fee token address
     * @dev Only the governance address can call this function
     * @dev The value of feeConfig may still be required to charge fees that were due before the removal
     */
    function removeFeeConfig(address _feeToken) external onlyGov {
        delete feeCurrencies[_feeToken];
        delete feeMinimumDeposit[_feeToken];
        delete payloadPerByteFee[_feeToken];
        // NOTE: gasPerEtherFee is not removed to allow for tx that were halfway done during fee token removal
        emit DeleteFeeConfig(_feeToken);
    }

    /**
     * @notice Set DApp configuration discount
     * @param _dappID The DApp ID
     * @param _discount The discount coefficient between 0 (no discount) and 10k (100% discount)
     * @dev Reverts if DApp ID is zero, discount is zero, or DApp is not active
     * @dev Only governance or DApp admin can call this function
     */
    function setDAppFeeDiscount(uint256 _dappID, uint256 _discount) external dappIDExists(_dappID) onlyGov {
        if (_discount > DISCOUNT_DENOMINATOR) {
            revert C3DAppManager_DiscountAboveMax(_discount, DISCOUNT_DENOMINATOR);
        }
        dappConfig[_dappID].discount = _discount;
        emit SetDAppFeeDiscount(_dappID, _discount);
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
        dappIDExists(_dappID)
        onlyGov
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
     * @notice Derive a DApp ID based on creator address and chosen DApp key
     * @param _creator The msg.sender of the initial DApp creation
     * @param _dappKey The chosen DApp key, in the form of "v1.protocolname.contractname"
     * @return Derived DApp ID
     */
    function deriveDAppID(address _creator, string memory _dappKey) external pure returns (uint256) {
        return _deriveDAppID(_creator, _dappKey);
    }

    /**
     * @notice Get all DApp addresses that have been added for a given DApp
     * @param _dappID The DApp ID
     * @return Array of DApp addresses
     */
    function getAllDAppAddrs(uint256 _dappID) external view returns (address[] memory) {
        return dappAddrs[_dappID];
    }

    /**
     * @notice Get all MPC addresses that have been added for a given DApp
     * @param _dappID The DApp ID
     * @return Array of MPC addresses
     */
    function getAllDAppMPCAddrs(uint256 _dappID) external view returns (address[] memory) {
        return dappMPCAddrs[_dappID];
    }

    /**
     * @notice Get the number of MPC addresses for a DApp
     * @param _dappID The DApp ID
     * @return The number of MPC addresses
     */
    function getDAppMPCCount(uint256 _dappID) external view returns (uint256) {
        return dappMPCAddrs[_dappID].length;
    }

    /**
     * @notice Checks if an MPC address has been whitelisted by the DApp to execute cross-chain transactions
     * @param _dappID The DApp ID
     * @param _sender The MPC address that is calling C3Caller.execute
     * @dev If the DApp admin has not whitelisted any MPC addresses, then assume they will allow any MPC address from
     * the public pool
     */
    function isValidMPCAddr(uint256 _dappID, address _sender) external view returns (bool) {
        return dappMPCAddrs[_dappID].length == 0 || dappMPCMembership[_dappID][_sender];
    }

    /**
     * @notice Get all DApp keys that `_creator` has initialized DApps with
     * @param _creator The address of the creator to check DApp keys
     * @dev This is useful for off-chain DApp ID derivation
     */
    function getAllCreatorDAppKeys(address _creator) external view returns (string[] memory) {
        return creatorDAppKeys[_creator];
    }

    /**
     * @notice Check DApp status
     * @param _dappID The dapp ID in question
     * @return Active, Dormant, Suspended or Deprecated
     * @dev Calling _parseDAppStatus to check for dormant status
     */
    function dappStatus(uint256 _dappID) external view dappIDExists(_dappID) returns (DAppStatus) {
        return _parseDAppStatus(_dappID);
    }

    /**
     * @notice Internal handler to set configuration for a new or old DApp ID
     * @param _dappID The ID of the DApp to configure
     * @param _feeToken The fee token to set
     * @param _admin The app admin to set
     * @param _metadata The JSON encoded DApp name, URL, description and email for the DApp
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
            revert C3DAppManager_StringTooLong(metadataLength, METADATA_LIMIT);
        }

        dappConfig[_dappID] = DAppConfig({
            admin: _admin,
            feeToken: _feeToken,
            discount: dappConfig[_dappID].discount,
            lastUpdated: msg.sender == gov() ? dappConfig[_dappID].lastUpdated : block.timestamp,
            metadata: _metadata
        });
    }

    /**
     * @notice Internal handler to deposit tokens to a DApp's staking pool
     * @param _dappID The DApp ID to deposit for
     * @param _feeToken The fee token to deposit to the pool
     * @param _amount The amount to deposit
     * @dev Reverts if the fee token is not supported or the amount is below minimum deposit
     */
    function _deposit(uint256 _dappID, address _feeToken, uint256 _amount)
        internal
    {
        if (!feeCurrencies[_feeToken]) {
            revert C3DAppManager_InvalidFeeToken(_feeToken);
        }
        uint256 minimum = feeMinimumDeposit[_feeToken];
        if (_amount < minimum) {
            revert C3DAppManager_BelowMinimumDeposit(_amount, minimum);
        }

        dappStakePool[_dappID][_feeToken] += _amount;

        uint256 contractBalInitial = IERC20(_feeToken).balanceOf(address(this));
        IERC20(_feeToken).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 contractBalFinal = IERC20(_feeToken).balanceOf(address(this));
        assert(contractBalFinal == contractBalInitial + _amount);

        emit Deposit(_dappID, _feeToken, _amount, dappStakePool[_dappID][_feeToken]);
    }

    /**
     * @notice Internal handler to derive a DApp ID based on creator address and chosen DApp key
     * @param _creator The msg.sender of the initial DApp creation
     * @param _dappKey The chosen DApp key, in the form of "v1.protocolname.contractname"
     * @return Derived DApp ID
     */
    function _deriveDAppID(address _creator, string memory _dappKey) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_creator, _dappKey)));
    }

    /**
     * @notice Check whether a derived DApp ID already exists, to prevent collisions
     * @param _dappID The DApp ID to check
     * @return True if the DApp ID exists
     */
    function _checkDAppIDExists(uint256 _dappID) internal view returns (bool) {
        return bytes(dappConfig[_dappID].metadata).length > 0;
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
     * @dev Internal function to authorize upgrades
     * @param newImplementation The new implementation address
     * @notice Only governance can authorize upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyGov {}
}
