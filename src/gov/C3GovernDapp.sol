// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { C3CallerDapp } from "../dapp/C3CallerDapp.sol";
import { IC3CallerDapp } from "../dapp/IC3CallerDapp.sol";
import { TheiaUtils } from "../theia/TheiaUtils.sol";
import { IC3GovernDapp } from "./IC3GovernDapp.sol";

abstract contract C3GovernDapp is C3CallerDapp, IC3GovernDapp {
    using Strings for *;
    using Address for address;

    /// @custom:storage-location erc7201:c3caller.storage.C3GovernDapp
    struct C3GovernDappStorage {
        uint256 delay; // delay for timelock functions
        address _oldGov;
        address _newGov;
        uint256 _newGovEffectiveTime;
        mapping(address => bool) txSenders;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3GovernDapp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3GovernDappStorageLocation =
        0xc8c66710888cf7a9b30b25a7681bee72e322593d6079d3f7101b3588b0dff800;

    function _getC3GovernDappStorage() private pure returns (C3GovernDappStorage storage $) {
        assembly {
            $.slot := C3GovernDappStorageLocation
        }
    }

    function __C3GovernDapp_init(address _gov, address _c3callerProxy, address _txSender, uint256 _dappID)
        internal
        onlyInitializing
    {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        __C3CallerDapp_init(_c3callerProxy, _dappID);
        $.delay = 2 days;
        $._oldGov = _gov;
        $._newGov = _gov;
        $._newGovEffectiveTime = block.timestamp;
        $.txSenders[_txSender] = true;
    }

    // TODO: replace c3caller.isCaller(address) with something else
    modifier onlyGov() {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        require(msg.sender == gov() || _isCaller(msg.sender), "Gov FORBIDDEN");
        _;
    }

    function delay() public view virtual returns (uint256) {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        return $.delay;
    }

    function txSenders(address sender) public view virtual returns (bool) {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        return $.txSenders[sender];
    }

    function gov() public view virtual returns (address) {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        if (block.timestamp >= $._newGovEffectiveTime) {
            return $._newGov;
        }
        return $._oldGov;
    }

    function changeGov(address newGov) external virtual onlyGov {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        require(newGov != address(0), "newGov is empty");
        $._oldGov = gov();
        $._newGov = newGov;
        $._newGovEffectiveTime = block.timestamp + $.delay;
        emit LogChangeGov($._oldGov, $._newGov, $._newGovEffectiveTime, block.chainid);
    }

    function setDelay(uint256 _delay) external virtual onlyGov {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        $.delay = _delay;
    }

    function addTxSender(address txSender) external virtual onlyGov {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        $.txSenders[txSender] = true;
        emit LogTxSender(txSender, true);
    }

    function disableTxSender(address txSender) external virtual onlyGov {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        $.txSenders[txSender] = false;
        emit LogTxSender(txSender, false);
    }

    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external virtual onlyGov {
        _c3call(_to, _toChainID, _data);
    }

    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data)
        external
        virtual
        onlyGov
    {
        require(_targets.length == _toChainIDs.length);
        _c3broadcast(_targets, _toChainIDs, _data);
    }

    function isValidSender(address txSender)
        external
        view
        virtual
        override(IC3CallerDapp, C3CallerDapp)
        returns (bool)
    {
        C3GovernDappStorage storage $ = _getC3GovernDappStorage();
        return $.txSenders[txSender];
    }
}
