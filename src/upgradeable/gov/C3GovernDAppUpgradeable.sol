// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IC3CallerDApp } from "../../dapp/IC3CallerDApp.sol";
import { C3CallerDAppUpgradeable } from "../dapp/C3CallerDAppUpgradeable.sol";

import { IC3GovernDApp } from "../../gov/IC3GovernDApp.sol";
import { C3ErrorParam } from "../../utils/C3CallerUtils.sol";

/**
 * @author @potti ContinuumDAO
 */
abstract contract C3GovernDAppUpgradeable is C3CallerDAppUpgradeable, IC3GovernDApp {
    using Strings for *;
    using Address for address;

    /// @custom:storage-location erc7201:c3caller.storage.C3GovernDApp
    struct C3GovernDAppStorage {
        uint256 delay; // delay for timelock functions
        address _oldGov;
        address _newGov;
        uint256 _newGovEffectiveTime;
        mapping(address => bool) txSenders;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3GovernDApp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3GovernDAppStorageLocation =
        0xc8c66710888cf7a9b30b25a7681bee72e322593d6079d3f7101b3588b0dff800;

    function _getC3GovernDAppStorage() private pure returns (C3GovernDAppStorage storage $) {
        assembly {
            $.slot := C3GovernDAppStorageLocation
        }
    }

    function __C3GovernDApp_init(address _gov, address _c3callerProxy, address _txSender, uint256 _dappID)
        internal
        onlyInitializing
    {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        __C3CallerDApp_init(_c3callerProxy, _dappID);
        $.delay = 2 days;
        $._oldGov = _gov;
        $._newGov = _gov;
        $._newGovEffectiveTime = block.timestamp;
        $.txSenders[_txSender] = true;
    }

    modifier onlyGov() {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        if (msg.sender != gov() && !_isCaller(msg.sender)) {
            revert C3GovernDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrC3Caller);
        }
        _;
    }

    function delay() public view virtual returns (uint256) {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        return $.delay;
    }

    function txSenders(address sender) public view virtual returns (bool) {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        return $.txSenders[sender];
    }

    function gov() public view virtual returns (address) {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        if (block.timestamp >= $._newGovEffectiveTime) {
            return $._newGov;
        }
        return $._oldGov;
    }

    function changeGov(address _newGov) external virtual onlyGov {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        if (_newGov == address(0)) {
            revert C3GovernDApp_IsZeroAddress(C3ErrorParam.Gov);
        }
        $._oldGov = gov();
        $._newGov = _newGov;
        $._newGovEffectiveTime = block.timestamp + $.delay;
        emit LogChangeGov($._oldGov, $._newGov, $._newGovEffectiveTime, block.chainid);
    }

    function setDelay(uint256 _delay) external virtual onlyGov {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        $.delay = _delay;
    }

    function addTxSender(address _txSender) external virtual onlyGov {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        $.txSenders[_txSender] = true;
        emit LogTxSender(_txSender, true);
    }

    function disableTxSender(address _txSender) external virtual onlyGov {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        $.txSenders[_txSender] = false;
        emit LogTxSender(_txSender, false);
    }

    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external virtual onlyGov {
        _c3call(_to, _toChainID, _data);
    }

    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data)
        external
        virtual
        onlyGov
    {
        if (_targets.length != _toChainIDs.length) {
            revert C3GovernDApp_LengthMismatch(C3ErrorParam.Target, C3ErrorParam.ChainID);
        }
        _c3broadcast(_targets, _toChainIDs, _data);
    }

    function isValidSender(address _txSender)
        external
        view
        virtual
        override(IC3CallerDApp, C3CallerDAppUpgradeable)
        returns (bool)
    {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        return $.txSenders[_txSender];
    }
}
