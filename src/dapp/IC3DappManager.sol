// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Account, Uint } from "../utils/C3CallerUtils.sol";

interface IC3DAppManager {
    // Dapp config
    struct DappConfig {
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

    error C3DAppManager_IsZero(Uint);
    error C3DAppManager_IsZeroAddress(Account);
    error C3DAppManager_InvalidDAppID(uint256);
    error C3DAppManager_NotZeroAddress(Account);
    error C3DAppManager_LengthMismatch(Uint, Uint);
    error C3DAppManager_OnlyAuthorized(Account, Account);
    error C3DAppManager_InsufficientBalance(address _token);
}
