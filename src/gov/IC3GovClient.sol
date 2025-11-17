// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

interface IC3GovClient {
    // Events
    event ChangeGov(address indexed _oldGov, address indexed _newGov);
    event ApplyGov(address indexed _oldGov, address indexed _newGov);
    event SetC3Caller(address indexed _oldC3Caller, address indexed _newC3Caller);

    // Errors
    error C3GovClient_OnlyAuthorized(C3ErrorParam, C3ErrorParam);

    // State
    function c3caller() external view returns (address);
    function gov() external view returns (address);
    function pendingGov() external view returns (address);

    // Mut
    function setC3Caller(address _c3caller) external;
    function changeGov(address _gov) external;
    function applyGov() external;
    function pause() external;
    function unpause() external;
}
