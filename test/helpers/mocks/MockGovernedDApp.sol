// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockGovernedDApp is Ownable {
    error Broken(uint256);

    uint256 sensitiveNumber = 0;

    constructor(address _owner) Ownable(_owner) {}

    function sensitiveNumberChange(uint256 _num) public onlyOwner returns (uint256) {
        if (_num % 5 == 0) {
            revert Broken(_num);
        }
        sensitiveNumber = _num;
        return sensitiveNumber;
    }
}
