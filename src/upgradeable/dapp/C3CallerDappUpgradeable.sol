// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IC3Caller } from "../../IC3Caller.sol";

import { IC3CallerDapp } from "../../dapp/IC3CallerDapp.sol";
import { C3ErrorParam } from "../../utils/C3CallerUtils.sol";

abstract contract C3CallerDappUpgradeable is IC3CallerDapp, Initializable {
    /// @custom:storage-location erc7201:c3caller.storage.C3CallerDapp
    struct C3CallerDappStorage {
        address c3CallerProxy;
        uint256 dappID;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3CallerDapp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3CallerDappStorageLocation =
        0xa39433114fd213b64ea52624936c26398cba31e0774cfae377a12cb547f1bb00;

    // INFO: UUPS config
    function _getC3CallerDappStorage() private pure returns (C3CallerDappStorage storage $) {
        assembly {
            $.slot := C3CallerDappStorageLocation
        }
    }

    function __C3CallerDapp_init(address _c3CallerProxy, uint256 _dappID) internal onlyInitializing {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        $.c3CallerProxy = _c3CallerProxy;
        $.dappID = _dappID;
    }

    modifier onlyCaller() {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        if (IC3Caller($.c3CallerProxy).isCaller(msg.sender)) {
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
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        if (_dappID != $.dappID) {
            revert C3CallerDApp_InvalidDAppID($.dappID, _dappID);
        }
        return _c3Fallback(bytes4(_data[0:4]), _data[4:], _reason);
    }

    function isValidSender(address _txSender) external view virtual returns (bool);

    // INFO: public
    function c3CallerProxy() public view virtual returns (address) {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return $.c3CallerProxy;
    }

    function dappID() public view virtual returns (uint256) {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return $.dappID;
    }

    // INFO: internal
    function _isCaller(address _addr) internal virtual returns (bool) {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return IC3Caller($.c3CallerProxy).isCaller(_addr);
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        virtual
        returns (bool);

    function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal virtual {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        IC3Caller($.c3CallerProxy).c3call($.dappID, _to, _toChainID, _data, "");
    }

    function _c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra)
        internal
        virtual
    {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        IC3Caller($.c3CallerProxy).c3call($.dappID, _to, _toChainID, _data, _extra);
    }

    function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal virtual {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        IC3Caller($.c3CallerProxy).c3broadcast($.dappID, _to, _toChainIDs, _data);
    }

    function _context()
        internal
        view
        virtual
        returns (bytes32 uuid, string memory fromChainID, string memory sourceTx)
    {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return IC3Caller($.c3CallerProxy).context();
    }
}
