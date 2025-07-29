// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Uint, Account} from "../utils/C3CallerUtils.sol";

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
    event SetBlacklists(uint256 dappID, bool flag);

    event SetDAppAddr(uint256 indexed dappID, string[] addresses);

    event AddMpcAddr(uint256 indexed dappID, string addr, string pubkey);

    event DelMpcAddr(uint256 indexed dappID, string addr, string pubkey);

    event SetFeeConfig(address indexed token, string chain, uint256 callPerByteFee);

    event Deposit(uint256 indexed dappID, address indexed token, uint256 amount, uint256 left);
    event Withdraw(uint256 indexed dappID, address indexed token, uint256 amount, uint256 left);
    event Charging(uint256 indexed dappID, address indexed token, uint256 bill, uint256 amount, uint256 left);

    error C3DAppManager_IsZero(Uint);
    error C3DAppManager_IsZeroAddress(Account);
    error C3DAppManager_InvalidDAppID(uint256);
    error C3DAppManager_NotZeroAddress(Account);
    error C3DAppManager_LengthMismatch(Uint, Uint);
    error C3DAppManager_OnlyAuthorized(Account, Account);
    error C3DAppManager_InsufficientBalance(address);
}
