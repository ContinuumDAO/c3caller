// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

interface IC3CallerProxy {
    function getImplementation() external view returns (address);
}
