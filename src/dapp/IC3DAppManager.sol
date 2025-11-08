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

    struct DAppConfig {
        address admin; // account who admin the application's config
        address feeToken; // token address for fee token
        uint256 discount; // discount
        uint256 lastUpdated;
        string metadata;
    }

    struct FeeConfig {
        uint256 perByte;
        uint256 perGas;
    }

    event DAppStatusChanged(
        uint256 indexed _dappID, DAppStatus indexed _oldStatus, DAppStatus indexed _newStatus, string _reason
    );
    event SetDAppConfig(
        uint256 indexed dappID, address indexed admin, address indexed feeToken, string metadata
    );
    event SetDAppAddr(uint256 _dappID, string[] _addresses);
    event AddMpcAddr(uint256 _dappID, string _addr, string _pubkey);
    event DelMpcAddr(uint256 _dappID, string _addr, string _pubkey);
    event SetFeeConfig(address _token, string _chain, uint256 _perByteFee, uint256 _perGasFee);
    event SetMinimumFeeDeposit(address _feeToken, uint256 _feeMinimumDeposit);
    event DeleteFeeConfig(address _token);
    event Deposit(uint256 _dappID, address _token, uint256 _amount, uint256 _left);
    event Withdraw(uint256 _dappID, address _token, uint256 _amount, uint256 _left);
    event Charging(uint256 _dappID, address _token, uint256 _bill, uint256 _discount, uint256 _left);

    error C3DAppManager_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3DAppManager_InactiveDApp(uint256 _dappID, DAppStatus);
    error C3DAppManager_ZeroDAppID();
    error C3DAppManager_InvalidStatusTransition(DAppStatus _from, DAppStatus _to);
    error C3DAppManager_RecentlyUpdated(uint256 _dappID);
    error C3DAppManager_InvalidFeeToken(address _token);
    error C3DAppManager_IsZero(C3ErrorParam);
    error C3DAppManager_MetadataTooLong(uint256 _length, uint256 _maxLength);
    error C3DAppManager_IsZeroAddress(C3ErrorParam);
    error C3DAppManager_LengthMismatch(C3ErrorParam, C3ErrorParam);
    error C3DAppManager_MpcAddressExists(string _addr);
    error C3DAppManager_MpcAddressNotFound(string _addr);
    error C3DAppManager_BelowMinimumDeposit(uint256 _amount, uint256 _minimum);
    error C3DAppManager_InsufficientBalance(address _token);
    error C3DAppManager_DiscountAboveMax();

    // Public variables
    function METADATA_LIMIT() external view returns (uint256);
    function dappID() external view returns (uint256);
    function dappConfig(uint256 _dappID)
        external
        view
        returns (address, address, uint256, uint256, string memory);
    function c3DAppAddr(string memory _addr) external view returns (uint256);
    function statusReason(uint256 _dappID) external view returns (string memory);
    function feeCurrencies(address _token) external view returns (bool);
    function dappStakePool(uint256 _dappID, address _token) external view returns (uint256);
    function specificChainFee(address _token, string memory _chain) external view returns (uint256, uint256);
    function cumulativeFees(address _token) external view returns (uint256);
    function mpcPubkey(uint256 _dappID, string memory _addr) external view returns (string memory);
    function mpcAddrs(uint256 _dappID, uint256 _index) external view returns (string memory);
    function mpcMembership(uint256 _dappID, string memory _addr) external view returns (bool);
    function feeMinimumDeposit(address _token) external view returns (uint256);

    // View functions
    function getAllMpcAddrs(uint256 _dappID) external view returns (string[] memory);
    function getMpcCount(uint256 _dappID) external view returns (uint256);
    function dappStatus(uint256 _dappID) external view returns (DAppStatus);

    // Mutable functions
    function pause() external;
    function unpause() external;
    function setDAppStatus(uint256 _dappID, DAppStatus _status, string memory _reason) external;
    function setDAppConfig(address _feeToken, string memory _metadata) external returns (uint256);
    function updateDAppConfig(
        uint256 _dappID,
        address _admin,
        address _feeToken,
        string memory _metadata
    ) external;
    function setDAppAddr(uint256 _dappID, string[] memory _addresses) external;
    function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external;
    function delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external;
    function setFeeConfig(address _token, string memory _chain, uint256 _perByteFee, uint256 _perGasFee) external;
    function setFeeMinimumDeposit(address _token, uint256 _minimumDeposit) external;
    function removeFeeConfig(address _token) external;
    function deposit(uint256 _dappID, address _token, uint256 _amount) external;
    function withdraw(uint256 _dappID, address _token) external;
    function charging(uint256 _dappID, address _token, uint256 _sizeBytes, uint256 _sizeGas, string memory _chain)
        external;
    function setDAppFeeDiscount(uint256 _dappID, uint256 _discount) external;
}
