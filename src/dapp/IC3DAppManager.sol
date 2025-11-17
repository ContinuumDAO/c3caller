// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

interface IC3DAppManager {
    enum DAppStatus {
        Active, // DApp is active and operational
        Dormant, // DApp's fee token is deprecated and DApp has not updated it
        Suspended, // DApp is temporarily suspended
        Deprecated // DApp is permanently deprecated and cannot be reused
    }

    enum FeeType {
        Payload,
        Gas
    }

    struct DAppConfig {
        address admin; // account who admin the application's config
        address feeToken; // token address for fee token
        uint256 discount; // discount
        uint256 lastUpdated;
        string metadata;
    }

    event DAppStatusChanged(
        uint256 indexed _dappID, DAppStatus indexed _oldStatus, DAppStatus indexed _newStatus, string _reason
    );
    event InitDAppConfig(uint256 indexed _dappID, string _dappKey, address indexed _admin, address indexed _feeToken, string metadata);
    event UpdateDAppConfig(uint256 indexed _dappID, address indexed _admin, address indexed _feeToken, string metadata);
    event SetDAppAddr(uint256 indexed _dappID, address[] _addresses);
    event AddMPCAddr(uint256 indexed _dappID, address _addr, string _pubkey);
    event DelMPCAddr(uint256 indexed _dappID, address _addr, string _pubkey);
    event SetFeeConfig(address indexed _token, uint256 _perByteFee, uint256 _perGasFee);
    event SetFeeMinimumDeposit(address indexed _feeToken, uint256 _feeMinimumDeposit);
    event DeleteFeeConfig(address indexed _token);
    event Deposit(uint256 indexed _dappID, address indexed _token, uint256 _amount, uint256 _left);
    event Withdraw(uint256 indexed _dappID, address indexed _token, uint256 _amount);
    event ChargePayload(uint256 indexed _dappID, address indexed _feeToken, uint256 _bill, uint256 _discount, uint256 _left);
    event ChargeGas(uint256 indexed _dappID, address indexed _feeToken, uint256 _bill, uint256 _left);
    event SetDAppFeeDiscount(uint256 indexed _dappID, uint256 _discount);

    error C3DAppManager_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3DAppManager_InactiveDApp(uint256 _dappID, DAppStatus);
    error C3DAppManager_InvalidDAppID(uint256 _dappID);
    error C3DAppManager_InvalidStatusTransition(DAppStatus _from, DAppStatus _to);
    error C3DAppManager_RecentlyUpdated(uint256 _dappID);
    error C3DAppManager_InvalidFeeToken(address _token);
    error C3DAppManager_IsZero(C3ErrorParam);
    error C3DAppManager_StringTooLong(uint256 _length, uint256 _maxLength);
    error C3DAppManager_IsZeroAddress(C3ErrorParam);
    error C3DAppManager_InvalidMPCAddress(address _addr);
    error C3DAppManager_MPCAddressExists(address _addr);
    error C3DAppManager_MPCAddressNotFound(address _addr);
    error C3DAppManager_BelowMinimumDeposit(uint256 _amount, uint256 _minimum);
    error C3DAppManager_InsufficientBalance(address _token);
    error C3DAppManager_DiscountAboveMax(uint256 _discount, uint256 _maxDiscount);

    // Public variables
    function METADATA_LIMIT() external view returns (uint256);
    function DISCOUNT_DENOMINATOR() external view returns (uint256);
    function dappIDRegistry() external view returns (uint256);
    function dappConfig(uint256 _dappID) external view returns (address, address, uint256, uint256, string memory);
    function c3DAppAddr(address _addr) external view returns (uint256);
    function statusReason(uint256 _dappID) external view returns (string memory);
    function feeCurrencies(address _token) external view returns (bool);
    function dappStakePool(uint256 _dappID, address _token) external view returns (uint256);
    function cumulativeFees(address _token) external view returns (uint256);
    function dappMPCPubkey(uint256 _dappID, address _addr) external view returns (string memory);
    function dappMPCAddrs(uint256 _dappID, uint256 _index) external view returns (address);
    function dappMPCMembership(uint256 _dappID, address _addr) external view returns (bool);
    function feeMinimumDeposit(address _token) external view returns (uint256);

    // View functions
    function getAllDAppMPCAddrs(uint256 _dappID) external view returns (address[] memory);
    function getDAppMPCCount(uint256 _dappID) external view returns (uint256);
    function dappStatus(uint256 _dappID) external view returns (DAppStatus);
    function getAllDAppKeysByCreator(address _creator) external view returns (string[] memory);

    // Mutable functions
    function setDAppStatus(uint256 _dappID, DAppStatus _status, string memory _reason) external;
    function initDAppConfig(string memory _dappKey, address _feeToken, string memory _metadata) external returns (uint256);
    function updateDAppConfig(uint256 _dappID, address _admin, address _feeToken, string memory _metadata) external;
    function setDAppAddr(uint256 _dappID, address[] memory _addresses) external;
    function addDAppMPCAddr(uint256 _dappID, address _addr, string memory _pubkey) external;
    function delDAppMPCAddr(uint256 _dappID, address _addr, string memory _pubkey) external;
    function setFeeConfig(address _token, uint256 _perByteFee, uint256 _perGasFee) external;
    function setFeeMinimumDeposit(address _token, uint256 _minimumDeposit) external;
    function removeFeeConfig(address _token) external;
    function deposit(uint256 _dappID, address _token, uint256 _amount) external;
    function withdraw(uint256 _dappID, address _token) external;
    function chargePayload(uint256 _dappID, uint256 _payloadSizeBytes) external;
    function chargeGas(uint256 _dappID, uint256 _gasSizeEther) external;
    function setDAppFeeDiscount(uint256 _dappID, uint256 _discount) external;
    function isValidMPCAddr(uint256 _dappID, address _sender) external view returns (bool);
}
