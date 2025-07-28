// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { Test } from "forge-std/Test.sol";

import { C3CallerProxy } from "../../src/utils/C3CallerProxy.sol";

contract Utils is Test {
    uint256 constant RWA_TYPE = 1;
    uint256 constant VERSION = 1;

    function getRevert(bytes calldata _payload) external pure returns (bytes memory) {
        return (abi.decode(_payload[4:], (bytes)));
    }

    function _deployProxy(address implementation, bytes memory _data) internal returns (address proxy) {
        proxy = address(new C3CallerProxy(implementation, _data));
    }
}
