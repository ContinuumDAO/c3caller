// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Account } from "../utils/C3CallerUtils.sol";

interface IC3GovClient {
    event ChangeGov(address indexed oldGov, address indexed newGov, uint256 timestamp);
    event ApplyGov(address indexed oldGov, address indexed newGov, uint256 timestamp);
    event AddOperator(address indexed op);

    error C3GovClient_OnlyAuthorized(Account, Account);
    error C3GovClient_IsZeroAddress(Account);
    error C3GovClient_AlreadyOperator(address);
    error C3GovClient_IsNotOperator(address);

    function gov() external view returns (address);
    function pendingGov() external view returns (address);
    function isOperator(address _sender) external view returns (bool);
    function operators(uint256 _index) external view returns (address);
    function applyGov() external;
    function getAllOperators() external view returns (address[] memory);
    function changeGov(address _gov) external;
    function addOperator(address _op) external;
    function revokeOperator(address _op) external;
}
