// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3GovClientUpgradeable} from "../../src/upgradeable/gov/C3GovClientUpgradeable.sol";

contract MockC3GovClientUpgradeable is C3GovClientUpgradeable {
    string public message;

    function initialize(address _gov) public initializer {
        __C3GovClient_init(_gov);
    }

    function mockFunctionOnlyGov(string memory _message) public onlyGov {
        message = _message;
    }

    function mockFunctionOnlyC3Caller(string memory _message) public onlyC3Caller {
        message = _message;
    }

    function mockFunctionWhenNotPaused(string memory _message) public whenNotPaused {
        message = _message;
    }
}
