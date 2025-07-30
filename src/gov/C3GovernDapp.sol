// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3CallerDapp } from "../dapp/C3CallerDapp.sol";
import { IC3CallerDapp } from "../dapp/IC3CallerDapp.sol";

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";
import { IC3GovernDapp } from "./IC3GovernDapp.sol";

abstract contract C3GovernDapp is C3CallerDapp, IC3GovernDapp {
    using Strings for *;
    using Address for address;

    uint256 public delay;
    address internal _oldGov;
    address internal _newGov;
    uint256 internal _newGovEffectiveTime;
    mapping(address => bool) internal _txSenders;

    constructor(address _gov, address _c3callerProxy, address _txSender, uint256 _dappID)
        C3CallerDapp(_c3callerProxy, _dappID)
    {
        delay = 2 days;
        _oldGov = _gov;
        _newGov = _gov;
        _newGovEffectiveTime = block.timestamp;
        _txSenders[_txSender] = true;
    }

    modifier onlyGov() {
        if (msg.sender != gov() && !_isCaller(msg.sender)) {
            revert C3GovernDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrC3Caller);
        }
        _;
    }

    function txSenders(address sender) public view returns (bool) {
        return _txSenders[sender];
    }

    function gov() public view returns (address) {
        if (block.timestamp >= _newGovEffectiveTime) {
            return _newGov;
        }
        return _oldGov;
    }

    function changeGov(address newGov_) external onlyGov {
        if (newGov_ == address(0)) {
            revert C3GovernDApp_IsZeroAddress(C3ErrorParam.Gov);
        }
        _oldGov = gov();
        _newGov = newGov_;
        _newGovEffectiveTime = block.timestamp + delay;
        emit LogChangeGov(_oldGov, _newGov, _newGovEffectiveTime, block.chainid);
    }

    function setDelay(uint256 _delay) external onlyGov {
        delay = _delay;
    }

    function addTxSender(address _txSender) external onlyGov {
        _txSenders[_txSender] = true;
        emit LogTxSender(_txSender, true);
    }

    function disableTxSender(address _txSender) external onlyGov {
        _txSenders[_txSender] = false;
        emit LogTxSender(_txSender, false);
    }

    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external onlyGov {
        _c3call(_to, _toChainID, _data);
    }

    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data)
        external
        onlyGov
    {
        if (_targets.length != _toChainIDs.length) {
            revert C3GovernDApp_LengthMismatch(C3ErrorParam.Target, C3ErrorParam.ChainID);
        }
        _c3broadcast(_targets, _toChainIDs, _data);
    }

    function isValidSender(address _txSender) external view override(IC3CallerDapp, C3CallerDapp) returns (bool) {
        return _txSenders[_txSender];
    }
}
