// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IC3GovClient } from "../../gov/IC3GovClient.sol";
import { C3ErrorParam } from "../../utils/C3CallerUtils.sol";

/**
 * @title C3GovClientUpgradeable
 * @dev Upgradeable base contract for governance client functionality in the C3 protocol.
 * This contract provides governance and operator management capabilities with upgradeable
 * storage using the ERC-7201 storage pattern.
 * 
 * Key features:
 * - Governance address management with pending changes
 * - Operator management (add/remove operators)
 * - Access control modifiers for governance and operators
 * - Event emission for governance changes
 * - Upgradeable storage using ERC-7201 pattern
 * 
 * @notice This contract provides the foundation for upgradeable governance functionality
 * @author @potti ContinuumDAO
 */
contract C3GovClientUpgradeable is IC3GovClient, Initializable {
    /**
     * @dev Storage struct for C3GovClient using ERC-7201 storage pattern
     * @custom:storage-location erc7201:c3caller.storage.C3GovClient
     */
    struct C3GovClientStorage {
        /// @notice The current governance address
        address gov;
        /// @notice The pending governance address (for two-step governance changes)
        address pendingGov;
        /// @notice Mapping of addresses to operator status
        mapping(address => bool) isOperator;
        /// @notice Array of all operator addresses
        address[] operators;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3GovClient")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3GovClientStorageLocation =
        0xfc30bbdfb847b0ba1d1dd9d15321eef3badc6d5d43505a7d5c3da71b05087100;

    /**
     * @dev Get the storage struct for C3GovClient
     * @return $ The storage struct
     */
    function _getC3GovClientStorage() private pure returns (C3GovClientStorage storage $) {
        assembly {
            $.slot := C3GovClientStorageLocation
        }
    }

    /**
     * @dev Modifier to restrict access to governance only
     * @notice Reverts if the caller is not the governor
     */
    modifier onlyGov() {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        // require(msg.sender == $.gov, "C3Gov: only Gov");
        if (msg.sender != $.gov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Gov);
        }
        _;
    }

    /**
     * @dev Modifier to restrict access to governance or operators
     * @notice Reverts if the caller is neither governor nor an operator
     */
    modifier onlyOperator() {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        // require(msg.sender == $.gov || $.isOperator[msg.sender], "C3Gov: only Operator");
        if (msg.sender != $.gov && !$.isOperator[msg.sender]) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrOperator);
        }
        _;
    }

    /**
     * @dev Internal function to initialize the upgradeable C3GovClient
     * @param _gov The initial governance address
     */
    function __C3GovClient_init(address _gov) internal onlyInitializing {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        $.gov = _gov;
        emit ApplyGov(address(0), _gov, block.timestamp);
    }

    /**
     * @notice Change the governance address (two-step process)
     * @dev Only the current governor can call this function
     * @param _gov The new governance address
     */
    function changeGov(address _gov) external onlyGov {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        $.pendingGov = _gov;
        emit ChangeGov($.gov, _gov, block.timestamp);
    }

    /**
     * @notice Apply the pending governance change
     * @dev Anyone can call this function to finalize the governance change
     * @notice Reverts if there is no pending governance address
     */
    function applyGov() external {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        // require($.pendingGov != address(0), "C3Gov: empty pendingGov");
        if ($.pendingGov == address(0)) {
            revert C3GovClient_IsZeroAddress(C3ErrorParam.Gov);
        }
        emit ApplyGov($.gov, $.pendingGov, block.timestamp);
        $.gov = $.pendingGov;
        $.pendingGov = address(0);
    }

    /**
     * @dev Internal function to add an operator
     * @param _op The address to add as an operator
     * @notice Reverts if the address is zero or already an operator
     */
    function _addOperator(address _op) internal {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        // require(op != address(0), "C3Caller: Operator is address(0)");
        if (_op == address(0)) {
            revert C3GovClient_IsZeroAddress(C3ErrorParam.Operator);
        }
        // require(!$.isOperator[op], "C3Caller: Operator already exists");
        if ($.isOperator[_op]) {
            revert C3GovClient_AlreadyOperator(_op);
        }
        $.isOperator[_op] = true;
        $.operators.push(_op);
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
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.operators;
    }

    /**
     * @notice Get the current governance address
     * @return The current governance address
     */
    function gov() public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.gov;
    }

    /**
     * @notice Get the pending governance address
     * @return The pending governance address
     */
    function pendingGov() public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.pendingGov;
    }

    /**
     * @notice Check if an address is an operator
     * @param _op The address to check
     * @return True if the address is an operator
     */
    function isOperator(address _op) public view returns (bool) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.isOperator[_op];
    }

    /**
     * @notice Get operator address by index
     * @param _index The index of the operator
     * @return The operator address at the specified index
     */
    function operators(uint256 _index) public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.operators[_index];
    }

    /**
     * @notice Revoke operator status from an address (governance only)
     * @dev Only the governor can call this function
     * @param _op The address to revoke operator status from
     * @notice Reverts if the address is not an operator
     */
    function revokeOperator(address _op) external onlyGov {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        // require($.isOperator[_op], "C3Caller: Operator not found");
        if (!$.isOperator[_op]) {
            revert C3GovClient_IsNotOperator(_op);
        }
        $.isOperator[_op] = false;
        uint256 _length = $.operators.length;
        for (uint256 _i = 0; _i < _length; _i++) {
            if ($.operators[_i] == _op) {
                $.operators[_i] = $.operators[_length - 1];
                $.operators.pop();
                return;
            }
        }
    }
}
