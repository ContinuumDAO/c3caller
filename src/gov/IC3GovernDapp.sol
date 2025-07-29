// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { IC3CallerDapp } from "../dapp/IC3CallerDapp.sol";
import { Account, Uint } from "../utils/C3CallerUtils.sol";

interface IC3GovernDapp is IC3CallerDapp {
    event LogChangeGov(
        address indexed _oldGov, address indexed _newGov, uint256 indexed _effectiveTime, uint256 _chainID
    );
    event LogTxSender(address indexed _txSender, bool _valid);

    error C3GovernDApp_OnlyAuthorized(Account, Account);
    error C3GovernDApp_IsZeroAddress(Account);
    error C3GovernDApp_LengthMismatch(Uint, Uint);

    // INFO: externals
    function changeGov(address _newGov) external;
    function setDelay(uint256 _delay) external;
    function addTxSender(address _txSender) external;
    function disableTxSender(address _txSender) external;
    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external;
    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data) external;

    // INFO: publics
    function delay() external view returns (uint256);
    function txSenders(address _sender) external view returns (bool);
    function gov() external view returns (address);

    // INFO: internals
    // function __C3GovernDapp_init(address _gov, address _c3callerProxy, address _txSender, uint256 _dappID) internal
    // onlyInitializing;
}
