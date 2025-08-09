// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3CallerDApp} from "../../../src/dapp/C3CallerDApp.sol";

contract MockC3CallerDApp is C3CallerDApp {
    uint256 public mockDAppID;
    address public mockC3CallerProxy;
    bool public isValidSenderResult;
    bool public shouldRevert;
    bytes public lastFallbackData;
    bytes public lastFallbackReason;
    bytes4 public lastFallbackSelector;

    constructor(address _c3CallerProxy, uint256 _dappID) C3CallerDApp(_c3CallerProxy, _dappID) {
        mockDAppID = _dappID;
        mockC3CallerProxy = _c3CallerProxy;
        isValidSenderResult = true;
        shouldRevert = false;
    }

    function setValidSenderResult(bool _result) external {
        isValidSenderResult = _result;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function isValidSender(address) external view override returns (bool) {
        return isValidSenderResult;
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason) internal override returns (bool) {
        if (shouldRevert) {
            revert("MockC3CallerDApp: intentional revert");
        }

        lastFallbackSelector = _selector;
        lastFallbackData = _data;
        lastFallbackReason = _reason;

        // Return true to simulate successful fallback
        return true;
    }

    // Function to simulate a successful call that returns 1
    function successfulCall() external view returns (uint256) {
        if (shouldRevert) {
            revert("MockC3CallerDApp: intentional revert");
        }
        return 1;
    }

    // Function to simulate a failed call that returns 0
    function failedCall() external pure returns (uint256) {
        return 0;
    }

    // Function to simulate a call that reverts
    function revertingCall() external pure {
        revert("MockC3CallerDApp: call reverted");
    }

    // Function to simulate a call that returns invalid data
    function invalidDataCall() external pure returns (bytes memory) {
        return "invalid";
    }

    function isCaller(address _sender) external returns (bool) {
        return _isCaller(_sender);
    }

    function c3call(string memory _to, string memory _toChainID, bytes memory _data) external {
        _c3call(_to, _toChainID, _data);
    }

    function c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra) external {
        _c3call(_to, _toChainID, _data, _extra);
    }

    function c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) external {
        _c3broadcast(_to, _toChainIDs, _data);
    }

    function context() external view returns (bytes32, string memory, string memory) {
        return _context();
    }
}
