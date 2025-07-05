// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IC3GovClient} from "./IC3GovClient.sol";

contract C3GovClientUpgradeable is IC3GovClient, Initializable {
    /// @custom:storage-location erc7201:c3caller.storage.C3GovClient
    struct C3GovClientStorage {
        address gov;
        address pendingGov;
        mapping (address => bool) isOperator;
        address[] operators;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3GovClient")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3GovClientStorageLocation = 0xfc30bbdfb847b0ba1d1dd9d15321eef3badc6d5d43505a7d5c3da71b05087100;

    function _getC3GovClientStorage() private pure returns (C3GovClientStorage storage $) {
        assembly {
            $.slot := C3GovClientStorageLocation
        }
    }

    event ChangeGov(
        address indexed oldGov,
        address indexed newGov,
        uint256 timestamp
    );

    event ApplyGov(
        address indexed oldGov,
        address indexed newGov,
        uint256 timestamp
    );

    event AddOperator(address indexed op);

    modifier onlyGov() {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        require(msg.sender == $.gov, "C3Gov: only Gov");
        _;
    }

    modifier onlyOperator() {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        require(
            msg.sender == $.gov || $.isOperator[msg.sender],
            "C3Gov: only Operator"
        );
        _;
    }

    function __C3GovClient_init(address _gov) internal initializer {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        $.gov = _gov;
        emit ApplyGov(address(0), _gov, block.timestamp);
    }

    function changeGov(address _gov) external onlyGov {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        $.pendingGov = _gov;
        emit ChangeGov($.gov, _gov, block.timestamp);
    }

    function applyGov() external {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        require($.pendingGov != address(0), "C3Gov: empty pendingGov");
        emit ApplyGov($.gov, $.pendingGov, block.timestamp);
        $.gov = $.pendingGov;
        $.pendingGov = address(0);
    }

    function _addOperator(address op) internal {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        require(op != address(0), "C3Caller: Operator is address(0)");
        require(!$.isOperator[op], "C3Caller: Operator already exists");
        $.isOperator[op] = true;
        $.operators.push(op);
        emit AddOperator(op);
    }

    function addOperator(address _op) external onlyGov {
        _addOperator(_op);
    }

    function getAllOperators() external view returns (address[] memory) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.operators;
    }

    function gov() public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.gov;
    }

    function pendingGov() public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.pendingGov;
    }

    function isOperator(address _op) public view returns (bool) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.isOperator[_op];
    }

    function operators() public view returns (address[] memory) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.operators;
    }

    function revokeOperator(address _op) external onlyGov {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        require($.isOperator[_op], "C3Caller: Operator not found");
        $.isOperator[_op] = false;
        uint256 length = $.operators.length;
        for (uint256 i = 0; i < length; i++) {
            if ($.operators[i] == _op) {
                $.operators[i] = $.operators[length - 1];
                $.operators.pop();
                return;
            }
        }
    }
}
