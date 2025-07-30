// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { IC3Caller } from "../IC3Caller.sol";

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";
import { IC3CallerDapp } from "./IC3CallerDapp.sol";

abstract contract C3CallerDapp is IC3CallerDapp {
    address public c3CallerProxy;
    uint256 public dappID;

    constructor(address _c3CallerProxy, uint256 _dappID) {
        c3CallerProxy = _c3CallerProxy;
        dappID = _dappID;
    }

    modifier onlyCaller() {
        if (!_isCaller(msg.sender)) {
            revert C3CallerDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.C3Caller);
        }
        _;
    }

    // INFO: externals
    function c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason)
        external
        virtual
        override
        onlyCaller
        returns (bool)
    {
        if (_dappID != dappID) {
            revert C3CallerDApp_InvalidDAppID(dappID, _dappID);
        }
        if (_data.length < 4) {
            return _c3Fallback(bytes4(0), _data, _reason);
        } else {
            return _c3Fallback(bytes4(_data[0:4]), _data[4:], _reason);
        }
    }

    function isValidSender(address _txSender) external view virtual returns (bool);

    // INFO: internal
    function _isCaller(address _addr) internal virtual returns (bool) {
        return IC3Caller(c3CallerProxy).isCaller(_addr);
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        virtual
        returns (bool);

    function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal virtual {
        IC3Caller(c3CallerProxy).c3call(dappID, _to, _toChainID, _data, "");
    }

    function _c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra)
        internal
        virtual
    {
        IC3Caller(c3CallerProxy).c3call(dappID, _to, _toChainID, _data, _extra);
    }

    function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal virtual {
        IC3Caller(c3CallerProxy).c3broadcast(dappID, _to, _toChainIDs, _data);
    }

    function _context()
        internal
        view
        virtual
        returns (bytes32 uuid, string memory fromChainID, string memory sourceTx)
    {
        return IC3Caller(c3CallerProxy).context();
    }
}
