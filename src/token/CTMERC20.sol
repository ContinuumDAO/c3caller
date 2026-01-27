// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {C3GovernDApp} from "../gov/C3GovernDApp.sol";
import {C3CallerUtils, C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {ICTMERC20} from "./ICTMERC20.sol";

abstract contract CTMERC20 is ICTMERC20, ERC20, C3GovernDApp {
    using C3CallerUtils for *;

    mapping(string => string) public peers;

    constructor(string memory _name, string memory _symbol, address _c3caller, uint256 _dappID)
        ERC20(_name, _symbol)
        C3GovernDApp(msg.sender, _c3caller, _dappID)
    {}

    function c3transfer(string memory _toStr, uint256 _amount, string memory _toChainIDStr)
        external
        virtual
        returns (bool)
    {
        if (bytes(peers[_toChainIDStr]).length == 0) revert CTMERC20_InvalidChainID(_toChainIDStr);
        if (bytes(_toStr).length == 0) revert CTMERC20_InvalidLength(C3ErrorParam.To);

        address _from = _msgSender();
        _burn(_from, _amount);

        bytes memory receiveData = abi.encodeWithSignature("c3receive(address,string,uint256)", _from, _toStr, _amount);
        _c3call(peers[_toChainIDStr], _toChainIDStr, receiveData);

        emit C3Transfer(_from, _toStr, _amount, _toChainIDStr);
        return true;
    }

    function c3transferFrom(address _from, string memory _toStr, uint256 _amount, string memory _toChainIDStr)
        external
        virtual
        returns (bool)
    {
        if (bytes(peers[_toChainIDStr]).length == 0) revert CTMERC20_InvalidChainID(_toChainIDStr);
        if (bytes(_toStr).length == 0) revert CTMERC20_InvalidLength(C3ErrorParam.To);

        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);

        bytes memory obtainCall = abi.encodeWithSignature("c3receive(address,string,uint256)", _from, _toStr, _amount);
        _c3call(peers[_toChainIDStr], _toChainIDStr, obtainCall);

        emit C3Transfer(_from, _toStr, _amount, _toChainIDStr);
        return true;
    }

    function c3receive(string memory _fromStr, string memory _toStr, uint256 _amount) public virtual onlyC3Caller {
        address _to = _toStr.toAddress();
        (, string memory _fromChainID,) = _context();
        _mint(_to, _amount);
        emit C3Receive(_fromStr, _to, _amount, _fromChainID);
    }

    function setPeer(string memory _toChainIDStr, string memory _peer) external virtual onlyGov {
        peers[_toChainIDStr] = _peer;
        emit SetPeer(_toChainIDStr, _peer);
    }

    function _c3Fallback(
        bytes4,
        /*_selector*/
        bytes calldata _data,
        bytes calldata /*_reason*/
    )
        internal
        virtual
        override
        returns (bool)
    {
        (string memory _fromStr,, uint256 _amount) = abi.decode(_data, (string, string, uint256));
        address _from = _fromStr.toAddress();
        _mint(_from, _amount);
        return true;
    }
}
