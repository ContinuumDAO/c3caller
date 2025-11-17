// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

interface IC3CallerDApp {
    // Errors
    error C3CallerDApp_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3CallerDApp_InvalidDAppID(uint256, uint256);

    // State
    function dappID() external view returns (uint256);
    function c3caller() external view returns (address);

    // Mut
    function c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason) external returns (bool);

    // Internal Mut
    // function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal virtual;
    // function _c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra) internal virtual;
    // function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal virtual;
    // function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason) internal virtual returns (bool);

    // Internal View
    // function _context() internal view virtual returns (bytes32 uuid, string memory fromChainID, string memory sourceTx);
}
