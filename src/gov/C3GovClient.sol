// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";
import { IC3GovClient } from "./IC3GovClient.sol";

/**
 * @title C3GovClient
 * @dev Base contract for governance client functionality in the C3 protocol.
 * This contract provides governance and operator management capabilities
 * that can be inherited by other contracts in the C3 ecosystem.
 * 
 * Key features:
 * - Governance address management with pending changes
 * - Operator management (add/remove operators)
 * - Access control modifiers for governance and operators
 * - Event emission for governance changes
 * 
 * @notice This contract provides the foundation for governance functionality
 * @author @potti ContinuumDAO
 */
contract C3GovClient is IC3GovClient {
    /// @notice The current governance address
    address public gov;
    
    /// @notice The pending governance address (for two-step governance changes)
    address public pendingGov;
    
    /// @notice Mapping of addresses to operator status
    mapping(address => bool) public isOperator;
    
    /// @notice Array of all operator addresses
    address[] public operators;

    /**
     * @dev Constructor for C3GovClient
     * @param _gov The initial governance address
     */
    constructor(address _gov) {
        gov = _gov;
        emit ApplyGov(address(0), _gov, block.timestamp);
    }

    /**
     * @dev Modifier to restrict access to governance only
     * @notice Reverts if the caller is not the governor
     */
    modifier onlyGov() {
        if (msg.sender != gov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Gov);
        }
        _;
    }

    /**
     * @dev Modifier to restrict access to governance or operators
     * @notice Reverts if the caller is neither governor nor an operator
     */
    modifier onlyOperator() {
        if (msg.sender != gov && !isOperator[msg.sender]) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrOperator);
        }
        _;
    }

    /**
     * @notice Change the governance address (two-step process)
     * @dev Only the current governor can call this function
     * @param _gov The new governance address
     */
    function changeGov(address _gov) external onlyGov {
        pendingGov = _gov;
        emit ChangeGov(gov, _gov, block.timestamp);
    }

    /**
     * @notice Apply the pending governance change
     * @dev Anyone can call this function to finalize the governance change
     * @notice Reverts if there is no pending governance address
     */
    function applyGov() external {
        if (pendingGov == address(0)) {
            revert C3GovClient_IsZeroAddress(C3ErrorParam.Gov);
        }
        emit ApplyGov(gov, pendingGov, block.timestamp);
        gov = pendingGov;
        pendingGov = address(0);
    }

    /**
     * @dev Internal function to add an operator
     * @param _op The address to add as an operator
     * @notice Reverts if the address is zero or already an operator
     */
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

    /**
     * @notice Add an operator (governance only)
     * @dev Only the governor can call this function
     * @param _op The address to add as an operator
     */
    function addOperator(address _op) external onlyGov {
        _addOperator(_op);
    }

    /**
     * @notice Get all operator addresses
     * @return Array of all operator addresses
     */
    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }

    /**
     * @notice Revoke operator status from an address (governance only)
     * @dev Only the governor can call this function
     * @param _op The address to revoke operator status from
     * @notice Reverts if the address is not an operator
     */
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
