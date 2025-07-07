// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

interface IC3GovernDapp {
    event LogChangeGov(address indexed oldGov, address indexed newGov, uint256 indexed effectiveTime, uint256 chainID);

    event LogTxSender(address indexed txSender, bool valid);

    function gov() external view returns (address);
    function changeGov(address newGov) external;
    function setDelay(uint256 _delay) external;
    function addTxSender(address txSender) external;
    function disableTxSender(address txSender) external;
    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external;
    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data) external;
}
