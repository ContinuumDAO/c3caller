// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {IC3GovClient} from "./IC3GovClient.sol";

/**
 * @title C3GovClient
 * @notice Base contract for governance client functionality in the C3 protocol.
 * This contract provides governance and operator management capabilities that can be inherited by other contracts
 * in the C3 ecosystem. The key difference between this contract and C3GovernDApp is that this contract does not
 * contain a DApp ID, as it is designed to provide governance functionality without cross-chain functionality.
 *
 * Examples of contracts that implement this contract are C3Caller, C3UUIDKeeper and C3DAppManager. These are protocol
 * contracts and therefore do not need to be a C3GovernDApp.
 *
 * Key features:
 * - Governance address management with pending changes
 * - Operator management (add/remove operators)
 * - Access control modifiers for governance and operators
 * - Event emission for governance changes
 *
 * @dev This contract provides the foundation for governance functionality
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
     * @notice Modifier to restrict access to governance only
     * @dev Reverts if the caller is not the governance address
     */
    modifier onlyGov() {
        if (msg.sender != gov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Gov);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to governance or operators
     * @dev Reverts if the caller is neither governance address nor an operator
     */
    modifier onlyOperator() {
        if (msg.sender != gov && !isOperator[msg.sender]) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrOperator);
        }
        _;
    }

    /**
     * @param _gov The initial governance address
     */
    constructor(address _gov) {
        gov = _gov;
        emit ApplyGov(address(0), _gov, block.timestamp);
    }

    /**
     * @notice Change the governance address (two-step process)
     * @param _gov The new governance address
     * @dev Only the current governance address can call this function
     */
    function changeGov(address _gov) external onlyGov {
        pendingGov = _gov;
        emit ChangeGov(gov, _gov, block.timestamp);
    }

    /**
     * @notice Apply the pending governance change
     * @notice Reverts if there is no pending governance address
     * @dev Anyone can call this function to finalize the governance change
     */
    function applyGov() external {
        // ISSUE: #1
        if (msg.sender != pendingGov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.PendingGov);
        }
        address oldGov = gov;
        address newGov = pendingGov;
        gov = pendingGov;
        pendingGov = address(0);
        emit ApplyGov(oldGov, newGov, block.timestamp);
    }

    /**
     * @notice Add an operator
     * @param _op The address to add as an operator
     * @dev Only the governance address can call this function
     */
    function addOperator(address _op) external onlyGov {
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
     * @notice Revoke operator status from an address
     * @param _op The address from which to revoke operator status
     * @dev Reverts if the address is already not an operator
     * @dev Only the governance address can call this function
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

    /**
     * @notice Get all operator addresses
     * @return Array of all operator addresses
     */
    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }
}
