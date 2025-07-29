// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import {IC3DAppManager} from "./IC3DappManager.sol";
import { C3GovClient } from "../gov/C3GovClient.sol";
import {Uint, Account} from "../utils/C3CallerUtils.sol";

contract C3DappManager is IC3DAppManager, C3GovClient, Pausable {
    using Strings for *;
    using SafeERC20 for IERC20;

    uint256 public dappID;

    mapping(uint256 => DappConfig) private dappConfig;
    mapping(string => uint256) public c3DappAddr;
    mapping(uint256 => bool) public appBlacklist;

    // key is asset address, value is callPerByteFee
    mapping(address => uint256) public feeCurrencies;
    mapping(uint256 => mapping(address => uint256)) public dappStakePool;

    mapping(string => mapping(address => uint256)) public speChainFees;

    mapping(address => uint256) private fees;

    mapping(uint256 => mapping(string => string)) public mpcPubkey; // key is mpc address
    mapping(uint256 => string[]) public mpcAddrs;

    constructor() {
        __C3GovClient_init(msg.sender);
    }

    modifier onlyGovOrAdmin(uint256 _dappID) {
        if (msg.sender != gov() && msg.sender != dappConfig[_dappID].appAdmin) revert C3DAppManager_OnlyAuthorized(Account.Sender, Account.GovOrAdmin);
        _;
    }

    function pause() public onlyGov {
        _pause();
    }

    function unpause() public onlyGov {
        _unpause();
    }

    function setBlacklists(uint256 _dappID, bool _flag) external onlyGov {
        appBlacklist[_dappID] = _flag;
        emit SetBlacklists(_dappID, _flag);
    }

    function setFeeCurrencies(address[] calldata _tokens, uint256[] calldata _callfee) external onlyGov {
        for (uint256 index = 0; index < _tokens.length; index++) {
            feeCurrencies[_tokens[index]] = _callfee[index];
            emit SetFeeConfig(_tokens[index], "0", _callfee[index]);
        }
    }

    function disableFeeCurrency(address _token) external onlyGov {
        delete feeCurrencies[_token];
        emit SetFeeConfig(_token, "0", 0);
    }

    function setSpeFeeConfigByChain(address _token, string calldata _chain, uint256 _callfee) external onlyGov {
        speChainFees[_chain][_token] = _callfee;
        emit SetFeeConfig(_token, _chain, _callfee);
    }

    function initDappConfig(
        address _feeToken,
        string calldata _appDomain,
        string calldata _email,
        string[] calldata _whitelist
    ) external {
        // require(feeCurrencies[_feeToken] > 0, "C3M: fee token not supported");
        if (feeCurrencies[_feeToken] == 0) revert C3DAppManager_IsZero(Uint.FeePerByte);
        // require(bytes(_appDomain).length > 0, "C3M: appDomain empty");
        if (bytes(_appDomain).length == 0) revert C3DAppManager_IsZero(Uint.AppDomain);
        // require(bytes(_email).length > 0, "C3M: email empty");
        if (bytes(_email).length == 0) revert C3DAppManager_IsZero(Uint.Email);

        dappID++;
        DappConfig storage config = dappConfig[dappID];
        config.id = dappID;
        config.appAdmin = msg.sender;
        config.feeToken = _feeToken;

        if (_whitelist.length > 0) {
            _setDappAddrlist(dappID, _whitelist);
        }

        emit SetDAppConfig(dappID, msg.sender, _feeToken, _appDomain, _email);
    }

    function _setDappAddrlist(uint256 _subscribeID, string[] memory _whitelist) internal {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            // NOTE: If address already registered on another chain, skip
            if (c3DappAddr[_whitelist[i]] != 0) {
                continue;
            }
            c3DappAddr[_whitelist[i]] = _subscribeID;
        }
        emit SetDAppAddr(_subscribeID, _whitelist);
    }

    // TODO add chains
    function addDappAddr(uint256 _dappID, string[] memory _whitelist) external onlyGovOrAdmin(_dappID) {
        DappConfig memory config = dappConfig[_dappID];

        // require(config.appAdmin != address(0), "C3M: app not exist");
        if (config.appAdmin == address(0)) revert C3DAppManager_IsZeroAddress(Account.Admin);

        _setDappAddrlist(_dappID, _whitelist);
    }

    function getTxSenders(uint256 _dappID) external view returns (string[] memory) {
        return mpcAddrs[_dappID];
    }

    function delWhitelists(uint256 _dappID, string[] memory _whitelist) external onlyGovOrAdmin(_dappID) {
        DappConfig memory config = dappConfig[_dappID];

        // require(config.appAdmin != address(0), "C3M: app not exist");
        if (config.appAdmin == address(0)) revert C3DAppManager_IsZeroAddress(Account.Admin);

        for (uint256 i = 0; i < _whitelist.length; i++) {
            // require(c3DappAddr[_whitelist[i]] == _dappID, "C3M: addr not exist");
            if (c3DappAddr[_whitelist[i]] != _dappID) revert C3DAppManager_InvalidDAppID(_dappID);
            c3DappAddr[_whitelist[i]] = 0;
        }
        emit SetDAppAddr(0, _whitelist);
    }

    function updateDAppConfig(uint256 _dappID, address _feeToken, string calldata _appID, string calldata _email)
        external
        onlyGovOrAdmin(_dappID)
    {
        DappConfig memory config = dappConfig[_dappID];

        // require(config.appAdmin != address(0), "C3M: app not exist");
        if (config.appAdmin == address(0)) revert C3DAppManager_NotZeroAddress(Account.Admin);
        // require(feeCurrencies[_feeToken] > 0, "C3M: fee token not supported");
        if (feeCurrencies[_feeToken] == 0) revert C3DAppManager_IsZero(Uint.FeePerByte);

        config.feeToken = _feeToken;

        emit SetDAppConfig(dappID, msg.sender, _feeToken, _appID, _email);
    }

    function addTxSender(uint256 _dappID, string[] calldata _addrs, string[] calldata _pubkeys) external onlyGovOrAdmin(_dappID) {
        DappConfig memory config = dappConfig[_dappID];
        // require(config.appAdmin != address(0), "C3M: app not exist");
        if (config.appAdmin == address(0)) revert C3DAppManager_IsZeroAddress(Account.Admin);
        // require(_addrs.length == _pubkeys.length, "C3M: length dismatch");
        if (_addrs.length != _pubkeys.length) revert C3DAppManager_LengthMismatch(Uint.Address, Uint.PubKey);

        for (uint256 index = 0; index < _addrs.length; index++) {
            mpcPubkey[_dappID][_addrs[index]] = _pubkeys[index];
            mpcAddrs[_dappID].push(_addrs[index]);
            emit AddMpcAddr(dappID, _addrs[index], _pubkeys[index]);
        }
    }

    function removeTxSender(uint256 _dappID, string[] calldata _addrs) external onlyGovOrAdmin(_dappID) {
        DappConfig memory config = dappConfig[_dappID];
        // require(config.appAdmin != address(0), "C3M: app not exist");
        if (config.appAdmin == address(0)) revert C3DAppManager_IsZeroAddress(Account.Admin);

        for (uint256 index = 0; index < _addrs.length; index++) {
            string memory pk = mpcPubkey[_dappID][_addrs[index]];
            delete mpcPubkey[_dappID][_addrs[index]];
            for (uint256 j = 0; j < mpcAddrs[_dappID].length; j++) {
                if (mpcAddrs[_dappID][j].equal(_addrs[index])) {
                    uint256 tmp = mpcAddrs[_dappID].length - 1;
                    mpcAddrs[_dappID][j] = mpcAddrs[_dappID][tmp];
                    mpcAddrs[_dappID].pop();
                    emit DelMpcAddr(_dappID, _addrs[index], pk);
                }
            }
        }
    }

    function resetAdmin(uint256 _dappID, address _newAdmin) external onlyGovOrAdmin(_dappID) {
        DappConfig storage config = dappConfig[_dappID];

        // require(config.appAdmin != address(0), "C3M: app not exist");
        if (config.appAdmin == address(0)) revert C3DAppManager_IsZeroAddress(Account.Admin);
        config.appAdmin = _newAdmin;
    }

    function updateDappByGov(uint256 _dappID, address _feeToken, uint256 _discount) external onlyOperator {
        DappConfig storage config = dappConfig[_dappID];

        // require(config.appAdmin != address(0), "C3M: app not exist");
        if (config.appAdmin == address(0)) revert C3DAppManager_IsZeroAddress(Account.Admin);
        // require(feeCurrencies[_feeToken] > 0, "C3M: fee token not supported");
        if (feeCurrencies[_feeToken] == 0) revert C3DAppManager_IsZero(Uint.FeePerByte);

        config.feeToken = _feeToken;
        config.discount = _discount;

        emit SetDAppConfig(_dappID, config.appAdmin, _feeToken, "", "");
    }

    function deposit(uint256 _dappID, address _token, uint256 _amount) external {
        DappConfig memory config = dappConfig[_dappID];
        // require(config.id > 0, "C3M: dapp not exist");
        if (config.id == 0) revert C3DAppManager_InvalidDAppID(config.id);
        // require(config.appAdmin == msg.sender, "C3M: forbidden");
        if (msg.sender != config.appAdmin) revert C3DAppManager_OnlyAuthorized(Account.Sender, Account.Admin);
        // require(feeCurrencies[_token] > 0, "C3M: fee token not supported");
        if (feeCurrencies[_token] == 0) revert C3DAppManager_IsZero(Uint.FeePerByte);
        uint256 old_balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 new_balance = IERC20(_token).balanceOf(address(this));
        // require(new_balance >= old_balance && new_balance <= old_balance + _amount);
        assert(new_balance >= old_balance && new_balance <= old_balance + _amount);
        uint256 balance = new_balance - old_balance;

        dappStakePool[_dappID][_token] += balance;
        emit Deposit(_dappID, _token, balance, dappStakePool[_dappID][_token]);
    }

    function withdraw(uint256 _dappID, address _token, uint256 _amount) external {
        // require(dappStakePool[_dappID][_token] >= _amount, "C3M: insufficient amount for dapp");
        if (dappStakePool[_dappID][_token] < _amount) revert C3DAppManager_InsufficientBalance(_token);
        // require(IERC20(_token).balanceOf(address(this)) >= _amount, "C3M: insufficient amount for request");
        if (IERC20(_token).balanceOf(address(this)) < _amount) revert C3DAppManager_InsufficientBalance(_token);
        DappConfig memory config = dappConfig[_dappID];
        // require(msg.sender == config.appAdmin, "C3M: forbid");
        if (msg.sender != config.appAdmin) revert C3DAppManager_OnlyAuthorized(Account.Sender, Account.Admin);
        IERC20(_token).safeTransfer(msg.sender, _amount);
        dappStakePool[_dappID][_token] -= _amount;
        emit Withdraw(_dappID, _token, _amount, dappStakePool[_dappID][_token]);
    }

    function charging(uint256[] calldata _dappIDs, address[] calldata _tokens, uint256[] calldata _amounts)
        external
        onlyOperator
    {
        // require(_dappIDs.length == _tokens.length && _dappIDs.length == _amounts.length, "C3M: length mismatch");
        if (_dappIDs.length != _tokens.length) revert C3DAppManager_LengthMismatch(Uint.DAppID, Uint.Token);

        for (uint256 index = 0; index < _dappIDs.length; index++) {
            uint256 _dappID = _dappIDs[index];
            address _token = _tokens[index];
            uint256 _amount = _amounts[index];
            if (dappStakePool[_dappID][_token] > _amount) {
                dappStakePool[_dappID][_token] -= _amount;
            } else {
                _amount = dappStakePool[_dappID][_token];
                dappStakePool[_dappID][_token] = 0;
            }
            fees[_token] += _amount;
            emit Charging(_dappID, _token, _amounts[index], _amount, dappStakePool[_dappID][_token]);
        }
    }

    function withdrawFees(address[] calldata _tokens) external onlyGov {
        _withdraw(_tokens, gov());
    }

    function withdrawFeesTo(address[] calldata _tokens, address to) external onlyOperator {
        _withdraw(_tokens, to);
    }

    function _withdraw(address[] calldata _tokens, address to) internal {
        for (uint256 index = 0; index < _tokens.length; index++) {
            if (fees[_tokens[index]] > 0) {
                IERC20(_tokens[index]).safeTransfer(to, fees[_tokens[index]]);
                fees[_tokens[index]] = 0;
            }
        }
    }
}
