// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IC3DAppManager } from "../../dapp/IC3DappManager.sol";
import { C3ErrorParam } from "../../utils/C3CallerUtils.sol";
import { C3GovClientUpgradeable } from "../gov/C3GovClientUpgradeable.sol";

contract C3DappManagerUpgradeable is IC3DAppManager, C3GovClientUpgradeable, PausableUpgradeable {
    using Strings for *;
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:c3caller.storage.C3DappManager
    struct C3DappManagerStorage {
        uint256 dappID;
        mapping(uint256 => DappConfig) dappConfig;
        mapping(string => uint256) c3DappAddr;
        mapping(uint256 => bool) appBlacklist;
        mapping(address => uint256) feeCurrencies;
        mapping(uint256 => mapping(address => uint256)) dappStakePool;
        mapping(string => mapping(address => uint256)) speChainFees;
        mapping(address => uint256) fees;
        mapping(uint256 => mapping(string => string)) mpcPubkey;
        mapping(uint256 => string[]) mpcAddrs;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3DappManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3DappManagerStorageLocation =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    function _getC3DappManagerStorage() private pure returns (C3DappManagerStorage storage $) {
        assembly {
            $.slot := C3DappManagerStorageLocation
        }
    }

    function __C3DappManager_init(address _gov) internal onlyInitializing {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        __C3GovClient_init(_gov);
        __Pausable_init();
        $.dappID = 0;
    }

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

    modifier onlyGovOrAdmin(uint256 _dappID) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if (msg.sender != gov() && msg.sender != $.dappConfig[_dappID].appAdmin) {
            revert C3DAppManager_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin);
        }
        _;
    }

    function pause() public onlyGov {
        _pause();
    }

    function unpause() public onlyGov {
        _unpause();
    }

    function setBlacklists(uint256 _dappID, bool _flag) external onlyGov {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        $.appBlacklist[_dappID] = _flag;
        emit SetBlacklists(_dappID, _flag);
    }

    function setDAppConfig(
        uint256 _dappID,
        address _appAdmin,
        address _feeToken,
        string memory _appDomain,
        string memory _email
    ) external onlyGov {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if (_feeToken == address(0)) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }
        if (bytes(_appDomain).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.AppDomain);
        }
        if (bytes(_email).length == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.Email);
        }

        $.dappConfig[_dappID] = DappConfig({ id: _dappID, appAdmin: _appAdmin, feeToken: _feeToken, discount: 0 });

        emit SetDAppConfig(_dappID, _appAdmin, _feeToken, _appDomain, _email);
    }

    function setDAppAddr(uint256 _dappID, string[] memory _addresses) external onlyGovOrAdmin(_dappID) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        for (uint256 i = 0; i < _addresses.length; i++) {
            $.c3DappAddr[_addresses[i]] = _dappID;
        }
        emit SetDAppAddr(_dappID, _addresses);
    }

    function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if ($.dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if ($.dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_NotZeroAddress(C3ErrorParam.Admin);
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

        $.mpcPubkey[_dappID][_addr] = _pubkey;
        $.mpcAddrs[_dappID].push(_addr);

        emit AddMpcAddr(_dappID, _addr, _pubkey);
    }

    function delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if ($.dappConfig[_dappID].appAdmin == address(0)) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_addr).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }
        if (bytes(_pubkey).length == 0) {
            revert C3DAppManager_IsZeroAddress(C3ErrorParam.Admin);
        }

        $.mpcPubkey[_dappID][_addr] = "";

        string[] storage addrs = $.mpcAddrs[_dappID];
        for (uint256 i = 0; i < addrs.length; i++) {
            if (keccak256(bytes(addrs[i])) == keccak256(bytes(_addr))) {
                addrs[i] = addrs[addrs.length - 1];
                addrs.pop();
                break;
            }
        }

        emit DelMpcAddr(_dappID, _addr, _pubkey);
    }

    function setFeeConfig(address _token, string memory _chain, uint256 _callPerByteFee) external onlyGov {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if (_callPerByteFee == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        $.feeCurrencies[_token] = _callPerByteFee;
        $.speChainFees[_chain][_token] = _callPerByteFee;

        emit SetFeeConfig(_token, _chain, _callPerByteFee);
    }

    function deposit(uint256 _dappID, address _token, uint256 _amount) external {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if (_amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        $.dappStakePool[_dappID][_token] += _amount;

        emit Deposit(_dappID, _token, _amount, $.dappStakePool[_dappID][_token]);
    }

    function withdraw(uint256 _dappID, address _token, uint256 _amount) external onlyGovOrAdmin(_dappID) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if (_amount == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        if ($.dappStakePool[_dappID][_token] < _amount) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        $.dappStakePool[_dappID][_token] -= _amount;

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdraw(_dappID, _token, _amount, $.dappStakePool[_dappID][_token]);
    }

    function charging(uint256 _dappID, address _token, uint256 _bill) external onlyGovOrAdmin(_dappID) {
        if (_bill == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.FeePerByte);
        }

        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        if ($.dappStakePool[_dappID][_token] < _bill) {
            revert C3DAppManager_InsufficientBalance(_token);
        }

        $.dappStakePool[_dappID][_token] -= _bill;

        emit Charging(_dappID, _token, _bill, _bill, $.dappStakePool[_dappID][_token]);
    }

    function dappID() external view returns (uint256) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.dappID;
    }

    function getDappConfig(uint256 _dappID) external view returns (DappConfig memory) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.dappConfig[_dappID];
    }

    function getMpcAddrs(uint256 _dappID) external view returns (string[] memory) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.mpcAddrs[_dappID];
    }

    function getMpcPubkey(uint256 _dappID, string memory _addr) external view returns (string memory) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.mpcPubkey[_dappID][_addr];
    }

    function getFeeCurrency(address _token) external view returns (uint256) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.feeCurrencies[_token];
    }

    function getSpeChainFee(string memory _chain, address _token) external view returns (uint256) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.speChainFees[_chain][_token];
    }

    function getDappStakePool(uint256 _dappID, address _token) external view returns (uint256) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.dappStakePool[_dappID][_token];
    }

    function getFee(address _token) external view returns (uint256) {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        return $.fees[_token];
    }

    function setFee(address _token, uint256 _fee) external onlyGov {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        $.fees[_token] = _fee;
    }

    function setDappID(uint256 _dappID) external onlyGov {
        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        $.dappID = _dappID;
    }

    function setDappConfigDiscount(uint256 _dappID, uint256 _discount) external onlyGovOrAdmin(_dappID) {
        if (_dappID == 0) {
            revert C3DAppManager_IsZero(C3ErrorParam.DAppID);
        }
        if (_discount == 0) {
            revert C3DAppManager_LengthMismatch(C3ErrorParam.DAppID, C3ErrorParam.Token);
        }

        C3DappManagerStorage storage $ = _getC3DappManagerStorage();
        $.dappConfig[_dappID].discount = _discount;
    }
}
