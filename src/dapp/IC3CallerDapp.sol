// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Account} from "../utils/C3CallerUtils.sol";

interface IC3CallerDapp {
    error C3CallerDApp_OnlyAuthorized(Account, Account);
    error C3CallerDApp_InvalidDAppID(uint256, uint256);

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
