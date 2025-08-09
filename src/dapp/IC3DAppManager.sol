// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";

interface IC3DAppManager {
    // DApp config
    struct DAppConfig {
        uint256 id;
        address appAdmin; // account who admin the application's config
        address feeToken; // token address for fee token
        uint256 discount; // discount
    }

    event SetDAppConfig(
        uint256 indexed dappID, address indexed appAdmin, address indexed feeToken, string appDomain, string email
    );
    event SetBlacklists(uint256 _dappID, bool _flag);

    event SetDAppAddr(uint256 _dappID, string[] _addresses);

    event AddMpcAddr(uint256 _dappID, string _addr, string _pubkey);

    event DelMpcAddr(uint256 _dappID, string _addr, string _pubkey);

    event SetFeeConfig(address _token, string _chain, uint256 _callPerByteFee);

    event Deposit(uint256 _dappID, address _token, uint256 _amount, uint256 _left);
    event Withdraw(uint256 _dappID, address _token, uint256 _amount, uint256 _left);
    event Charging(uint256 _dappID, address _token, uint256 _bill, uint256 _amount, uint256 _left);

    error C3DAppManager_IsZero(C3ErrorParam);
    error C3DAppManager_IsZeroAddress(C3ErrorParam);
    error C3DAppManager_InvalidDAppID(uint256);
    error C3DAppManager_NotZeroAddress(C3ErrorParam);
    error C3DAppManager_LengthMismatch(C3ErrorParam, C3ErrorParam);
    error C3DAppManager_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3DAppManager_InsufficientBalance(address _token);

    // Public functions
    function pause() external;
    function unpause() external;
    function dappID() external view returns (uint256);

    // Public variables
    function c3DAppAddr(string memory _addr) external view returns (uint256);
    function appBlacklist(uint256 _dappID) external view returns (bool);
    function feeCurrencies(address _token) external view returns (uint256);
    function dappStakePool(uint256 _dappID, address _token) external view returns (uint256);
    function speChainFees(string memory _chain, address _token) external view returns (uint256);
    function mpcPubkey(uint256 _dappID, string memory _addr) external view returns (string memory);
    function mpcAddrs(uint256 _dappID, uint256 _index) external view returns (string memory);

    // External functions
    function setBlacklists(uint256 _dappID, bool _flag) external;
    function setDAppConfig(
        uint256 _dappID,
        address _appAdmin,
        address _feeToken,
        string memory _appDomain,
        string memory _email
    ) external;
    function setDAppAddr(uint256 _dappID, string[] memory _addresses) external;
    function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external;
    function delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external;
    function setFeeConfig(address _token, string memory _chain, uint256 _callPerByteFee) external;
    function deposit(uint256 _dappID, address _token, uint256 _amount) external;
    function withdraw(uint256 _dappID, address _token, uint256 _amount) external;
    function charging(uint256 _dappID, address _token, uint256 _bill) external;
    function getDAppConfig(uint256 _dappID) external view returns (DAppConfig memory);
    function getMpcAddrs(uint256 _dappID) external view returns (string[] memory);
    function getMpcPubkey(uint256 _dappID, string memory _addr) external view returns (string memory);
    function getFeeCurrency(address _token) external view returns (uint256);
    function getSpeChainFee(string memory _chain, address _token) external view returns (uint256);
    function getDAppStakePool(uint256 _dappID, address _token) external view returns (uint256);
    function getFee(address _token) external view returns (uint256);
    function setFee(address _token, uint256 _fee) external;
    function setDAppID(uint256 _dappID) external;
    function setDAppConfigDiscount(uint256 _dappID, uint256 _discount) external;
}
