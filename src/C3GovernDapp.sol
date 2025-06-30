// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {C3CallerDapp} from "./C3CallerDapp.sol";
import {C3GovClient} from "./C3GovClient.sol";
import {TheiaUtils} from "./TheiaUtils.sol";

abstract contract C3GovernDapp is C3CallerDapp {
    using Strings for *;
    using Address for address;
    // delay for timelock functions
    uint public delay = 2 days;

    address private _oldGov;
    address private _newGov;
    uint256 private _newGovEffectiveTime;

    mapping(address => bool) txSenders;

    constructor(
        address _gov,
        address _c3callerProxy,
        address _txSender,
        uint256 _dappID
    ) C3CallerDapp(_c3callerProxy, _dappID) {
        _oldGov = _gov;
        _newGov = _gov;
        _newGovEffectiveTime = block.timestamp;
        txSenders[_txSender] = true;
    }

    event LogChangeGov(
        address indexed oldGov,
        address indexed newGov,
        uint indexed effectiveTime,
        uint256 chainID
    );

    event LogTxSender(address indexed txSender, bool vaild);

    modifier onlyGov() {
        require(msg.sender == gov() || isCaller(msg.sender), "Gov FORBIDDEN");
        _;
    }

    function gov() public view returns (address) {
        if (block.timestamp >= _newGovEffectiveTime) {
            return _newGov;
        }
        return _oldGov;
    }

    function changeGov(address newGov) external onlyGov {
        require(newGov != address(0), "newGov is empty");
        _oldGov = gov();
        _newGov = newGov;
        _newGovEffectiveTime = block.timestamp + delay;
        emit LogChangeGov(
            _oldGov,
            _newGov,
            _newGovEffectiveTime,
            block.chainid
        );
    }

    function setDelay(uint _delay) external onlyGov {
        delay = _delay;
    }

    function addTxSender(address txSender) external onlyGov {
        txSenders[txSender] = true;
        emit LogTxSender(txSender, true);
    }

    function disableTxSender(address txSender) external onlyGov {
        txSenders[txSender] = false;
        emit LogTxSender(txSender, false);
    }

    function isVaildSender(address txSender) external view returns (bool) {
        return txSenders[txSender];
    }

    function doGov(
        string memory _to,
        string memory _toChainID,
        bytes memory _data
    ) external onlyGov {
        c3call(_to, _toChainID, _data);
    }

    function doGovBroadcast(
        string[] memory _targets,
        string[] memory _toChainIDs,
        bytes memory _data
    ) external onlyGov {
        require(_targets.length == _toChainIDs.length, "");
        c3broadcast(_targets, _toChainIDs, _data);
    }
}
