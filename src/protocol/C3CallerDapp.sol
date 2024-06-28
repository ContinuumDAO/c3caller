// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IC3Caller.sol";

abstract contract C3CallerDapp is IC3Dapp {
    address public c3CallerProxy;
    uint256 public dappID;

    modifier onlyCaller() {
        require(
            IC3CallerProxy(c3CallerProxy).isCaller(msg.sender),
            "C3CallerDapp: onlyCaller"
        );
        _;
    }

    constructor(address _c3CallerProxy, uint256 _dappID) {
        c3CallerProxy = _c3CallerProxy;
        dappID = _dappID;
    }

    function isCaller(address addr) internal returns (bool) {
        return IC3CallerProxy(c3CallerProxy).isCaller(addr);
    }

    function _c3Fallback(
        bytes4 selector,
        bytes calldata data,
        bytes calldata reason
    ) internal virtual returns (bool);

    function c3Fallback(
        uint256 _dappID,
        bytes calldata _data,
        bytes calldata _reason
    ) external override onlyCaller returns (bool) {
        require(_dappID == dappID, "dappID dismatch");
        return _c3Fallback(bytes4(_data[0:4]), _data[4:], _reason);
    }

    function context()
        internal
        view
        returns (
            bytes32 uuid,
            string memory fromChainID,
            string memory sourceTx
        )
    {
        return IC3CallerProxy(c3CallerProxy).context();
    }

    function c3call(
        string memory _to,
        string memory _toChainID,
        bytes memory _data
    ) internal {
        IC3CallerProxy(c3CallerProxy).c3call(
            dappID,
            _to,
            _toChainID,
            _data,
            ""
        );
    }

    function c3call(
        string memory _to,
        string memory _toChainID,
        bytes memory _data,
        bytes memory _extra
    ) internal {
        IC3CallerProxy(c3CallerProxy).c3call(
            dappID,
            _to,
            _toChainID,
            _data,
            _extra
        );
    }

    function c3broadcast(
        string[] memory _to,
        string[] memory _toChainIDs,
        bytes memory _data
    ) internal {
        IC3CallerProxy(c3CallerProxy).c3broadcast(
            dappID,
            _to,
            _toChainIDs,
            _data
        );
    }
}
