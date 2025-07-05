// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IC3GovClient {
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

    function gov() external view returns (address);
    function pendingGov() external view returns (address);
    function isOperator(address sender) external view returns (bool);
    function operators(uint256 index) external view returns (address);
    function applyGov() external;
    function getAllOperators() external view returns (address[] memory);

    // INFO: GOV only functions
    function changeGov(address _gov) external;
    function addOperator(address _op) external;
    function revokeOperator(address _op) external;
}
