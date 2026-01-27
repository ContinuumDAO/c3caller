// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

interface ICTMERC20 {
    event SetPeer(string indexed _chainIDstr, string _peer);

    event C3Transfer(address indexed _from, string indexed _toStr, uint256 _amount, string _toChainIDStr);
    event C3Receive(string indexed _fromStr, address indexed _to, uint256 _amount, string _fromChainIDStr);

    error CTMERC20_InvalidChainID(string _chainIDStr);
    error CTMERC20_InvalidLength(C3ErrorParam);

    function peers(string memory _chainIDStr) external view returns (string memory);
    function c3transfer(string memory _toStr, uint256 _amount, string memory _chainIDStr) external returns (bool);
    function c3transferFrom(address _from, string memory _toStr, uint256 _amount, string memory _chainIDStr)
        external
        returns (bool);
    function c3receive(string memory _fromStr, address _to, uint256 _amount) external;
    function setPeer(string memory _chainIDStr, string memory _peer) external;
}
