// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {C3GovernDApp} from "../../src/gov/C3GovernDApp.sol";

contract MockC3GovernDApp is C3GovernDApp {
    using Strings for address;

    string public outgoingMessage;
    string public incomingMessage;

    bytes4 public selector;
    bytes public reason;
    string public fallbackMessage;

    bytes32 public uuid;
    string public fromChainID;
    string public sourceTx;

    error TargetCallFailed();

    constructor(address _gov, address _c3caller, uint256 _dappID) C3GovernDApp(_gov, _c3caller, _dappID) {}

    function mockC3Executable(string memory _incomingMessage) public onlyC3Caller {
        incomingMessage = _incomingMessage;
        (uuid, fromChainID, sourceTx) = _context();
    }

    function mockC3ExecutableRevert() public onlyC3Caller {
        uuid = keccak256("execute revert");
        revert TargetCallFailed();
    }

    function mockC3ExecutableGov(string memory _incomingMessage) public onlyGov {
        incomingMessage = _incomingMessage;
        (uuid, fromChainID, sourceTx) = _context();
    }

    function mockC3ExecutableRevertGov() public onlyGov {
        uuid = keccak256("execute revert gov");
        revert TargetCallFailed();
    }

    function mockC3Call(address _target, string memory _toChainID, string memory _message) public {
        bytes memory data = abi.encodeWithSelector(this.mockC3Executable.selector, _message);
        _c3call(_target.toHexString(), _toChainID, data, "");
    }

    function mockC3CallWithExtra(address _target, string memory _toChainID, string memory _message, string memory extra) public {
        bytes memory data = abi.encodeWithSelector(this.mockC3Executable.selector, _message);
        _c3call(_target.toHexString(), _toChainID, data, bytes(extra));
    }

    function mockC3Broadcast(address[] memory _targets, string[] memory _toChainIDs, string memory _message) public {
        string[] memory _targetStrs = new string[](_targets.length);
        for (uint256 i = 0; i < _targets.length; i++) {
            _targetStrs[i] = _targets[i].toHexString();
        }
        bytes memory data = abi.encodeWithSelector(this.mockC3Executable.selector, _message);
        _c3broadcast(_targetStrs, _toChainIDs, data);
    }

    function _c3Fallback(
        bytes4 _selector,
        bytes calldata _data,
        bytes calldata _reason
    ) internal override returns (bool) {
        if (_selector == this.mockC3Executable.selector) {
            reason = _reason;
            (string memory _fallbackMessage) = abi.decode(_data, (string));
            (uuid, fromChainID, sourceTx) = _context();
            fallbackMessage = _fallbackMessage;
            return true;
        } else {
            selector = _selector;
            return false;
        }
    }
}
