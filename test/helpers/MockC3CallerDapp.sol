// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { IC3Caller } from "../../src/IC3Caller.sol";
import { IC3CallerDapp } from "../../src/dapp/IC3CallerDapp.sol";
import { C3ErrorParam } from "../../src/utils/C3CallerUtils.sol";

contract MockC3CallerDapp is IC3CallerDapp {
    uint256 public mockDappID;
    address public mockC3CallerProxy;
    bool public isValidSenderResult;
    bool public shouldRevert;
    bytes public lastFallbackData;
    bytes public lastFallbackReason;
    bytes4 public lastFallbackSelector;

    constructor(address _c3CallerProxy, uint256 _dappID) {
        mockDappID = _dappID;
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

    function c3CallerProxy() public view override returns (address) {
        return mockC3CallerProxy;
    }

    function dappID() public view override returns (uint256) {
        return mockDappID;
    }

    function c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason)
        external
        override
        returns (bool)
    {
        if (_dappID != mockDappID) {
            revert C3CallerDApp_InvalidDAppID(mockDappID, _dappID);
        }

        if (shouldRevert) {
            revert("MockC3CallerDapp: intentional revert");
        }

        if (_data.length >= 4) {
            lastFallbackSelector = bytes4(_data[0:4]);
            lastFallbackData = _data[4:];
        } else {
            lastFallbackSelector = bytes4(0);
            lastFallbackData = _data;
        }
        lastFallbackReason = _reason;

        // Return true to simulate successful fallback
        return true;
    }

    // Function to simulate a successful call that returns 1
    function successfulCall() external view returns (uint256) {
        if (shouldRevert) {
            revert("MockC3CallerDapp: intentional revert");
        }
        return 1;
    }

    // Function to simulate a failed call that returns 0
    function failedCall() external pure returns (uint256) {
        return 0;
    }

    // Function to simulate a call that reverts
    function revertingCall() external pure {
        revert("MockC3CallerDapp: call reverted");
    }

    // Function to simulate a call that returns invalid data
    function invalidDataCall() external pure returns (bytes memory) {
        return "invalid";
    }
}
