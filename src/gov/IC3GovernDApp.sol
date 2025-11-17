// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3CallerDApp} from "../dapp/IC3CallerDApp.sol";
import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

interface IC3GovernDApp is IC3CallerDApp {
    // Events
    event LogChangeGov(
        address indexed _oldGov, address indexed _newGov, uint256 indexed _effectiveTime, uint256 _chainID
    );

    // Errors
    error C3GovernDApp_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
    error C3GovernDApp_IsZeroAddress(C3ErrorParam);

    // State 
    function delay() external view returns (uint256);

    // Mut
    function changeGov(address _newGov) external;
    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external;
    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data) external;
    function setDelay(uint256 _delay) external;

    // View
    function gov() external view returns (address);

    // Internal View
    // function _oldGov() internal view returns (address);
    // function _newGov() internal view returns (address);
    // function _newGovEffectiveTime() internal view returns (uint256);
}
