// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";
import { IC3GovClient } from "./IC3GovClient.sol";

contract C3GovClient is IC3GovClient {
    address public gov;
    address public pendingGov;
    mapping(address => bool) public isOperator;
    address[] public operators;

    constructor(address _gov) {
        gov = _gov;
        emit ApplyGov(address(0), _gov, block.timestamp);
    }

    modifier onlyGov() {
        if (msg.sender != gov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Gov);
        }
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != gov && !isOperator[msg.sender]) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrOperator);
        }
        _;
    }

    function changeGov(address _gov) external onlyGov {
        pendingGov = _gov;
        emit ChangeGov(gov, _gov, block.timestamp);
    }

    function applyGov() external {
        if (pendingGov == address(0)) {
            revert C3GovClient_IsZeroAddress(C3ErrorParam.Gov);
        }
        emit ApplyGov(gov, pendingGov, block.timestamp);
        gov = pendingGov;
        pendingGov = address(0);
    }

    function _addOperator(address _op) internal {
        if (_op == address(0)) {
            revert C3GovClient_IsZeroAddress(C3ErrorParam.Operator);
        }
        if (isOperator[_op]) {
            revert C3GovClient_AlreadyOperator(_op);
        }
        isOperator[_op] = true;
        operators.push(_op);
        emit AddOperator(_op);
    }

    function addOperator(address _op) external onlyGov {
        _addOperator(_op);
    }

    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }

    function revokeOperator(address _op) external onlyGov {
        if (!isOperator[_op]) {
            revert C3GovClient_IsNotOperator(_op);
        }
        isOperator[_op] = false;
        uint256 _length = operators.length;
        for (uint256 _i = 0; _i < _length; _i++) {
            if (operators[_i] == _op) {
                operators[_i] = operators[_length - 1];
                operators.pop();
                return;
            }
        }
    }
}
