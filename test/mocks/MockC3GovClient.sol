// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3GovClient} from "../../src/gov/C3GovClient.sol";

contract MockC3GovClient is C3GovClient {
    string public message;

    constructor(address _c3caller, address _gov) C3GovClient(_gov) {
        c3caller = _c3caller;
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
