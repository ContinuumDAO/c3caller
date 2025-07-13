// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

interface IC3CallerDapp {
    // INFO: externals
    function c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason) external returns (bool);
    function isValidSender(address txSender) external view returns (bool);

    // INFO: publics
    function c3CallerProxy() external view returns (address);
    function dappID() external view returns (uint256);

    // INFO: internals
    // function __C3CallerDapp_init(address _c3CallerProxy, uint256 _dappID) internal onlyInitializing
    // function _isCaller(address addr) internal returns (bool) {
    // function _c3Fallback(bytes4 selector, bytes calldata data, bytes calldata reason) internal returns (bool);
    // function _context() internal view returns (bytes32 uuid, string memory fromChainID, string memory sourceTx) {
    // function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal {
    // function _c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra) internal {
    // function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal {
}
