// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { IC3Caller } from "./IC3Caller.sol";
import { IC3CallerDapp } from "./dapp/IC3CallerDapp.sol";

import { C3GovClient } from "./gov/C3GovClient.sol";
import { IC3UUIDKeeper } from "./uuid/IC3UUIDKeeper.sol";

import { Account, Uint } from "./utils/C3CallerUtils.sol";

contract C3Caller is IC3Caller, C3GovClient, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using Address for address;
    using Address for address payable;

    struct C3Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
    }

    C3Context public context;
    address public uuidKeeper;

    function initialize(address _swapIDKeeper) public initializer {
        __UUPSUpgradeable_init();
        __C3GovClient_init(msg.sender);
        __Ownable_init(msg.sender);
        __Pausable_init();
        uuidKeeper = _swapIDKeeper;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOperator { }

    function isExecutor(address _sender) external view returns (bool) {
        return isOperator(_sender);
    }

    function c3caller() public view returns (address) {
        return address(this);
    }

    function isCaller(address _sender) external view returns (bool) {
        // return sender == c3caller;
        return _sender == address(this);
    }

    function _c3call(
        uint256 _dappID,
        address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) internal {
        // require(_dappID > 0, "C3Caller: empty dappID");
        if (_dappID == 0) {
            revert C3Caller_IsZero(Uint.DAppID);
        }
        // require(bytes(_to).length > 0, "C3Caller: empty _to");
        if (bytes(_to).length == 0) {
            revert C3Caller_InvalidAccountLength(Account.To);
        }
        // require(bytes(_toChainID).length > 0, "C3Caller: empty toChainID");
        if (bytes(_toChainID).length == 0) {
            revert C3Caller_InvalidLength(Uint.ChainID);
        }
        // require(_data.length > 0, "C3Caller: empty calldata");
        if (_data.length == 0) {
            revert C3Caller_InvalidLength(Uint.Calldata);
        }
        bytes32 _uuid = IC3UUIDKeeper(uuidKeeper).genUUID(_dappID, _to, _toChainID, _data);
        emit LogC3Call(_dappID, _uuid, _caller, _toChainID, _to, _data, _extra);
    }

    // called by dapp
    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external whenNotPaused {
        _c3call(_dappID, msg.sender, _to, _toChainID, _data, _extra);
    }

    // called by dapp
    function c3call(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)
        external
        whenNotPaused
    {
        _c3call(_dappID, msg.sender, _to, _toChainID, _data, "");
    }

    function _c3broadcast(
        uint256 _dappID,
        address _caller,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) internal {
        // require(_dappID > 0, "C3Caller: empty dappID");
        if (_dappID == 0) {
            revert C3Caller_IsZero(Uint.DAppID);
        }
        // require(_to.length > 0, "C3Caller: empty _to");
        if (_to.length == 0) {
            revert C3Caller_InvalidAccountLength(Account.To);
        }
        // require(_toChainIDs.length > 0, "C3Caller: empty toChainID");
        if (_toChainIDs.length == 0) {
            revert C3Caller_InvalidLength(Uint.ChainID);
        }
        // require(_data.length > 0, "C3Caller: empty calldata");
        if (_data.length == 0) {
            revert C3Caller_InvalidLength(Uint.Calldata);
        }
        // require(_data.length == _toChainIDs.length, "C3Caller: calldata length dismatch");
        if (_data.length != _toChainIDs.length) {
            revert C3Caller_LengthMismatch(Uint.Calldata, Uint.ChainID);
        }

        for (uint256 i = 0; i < _toChainIDs.length; i++) {
            bytes32 _uuid = IC3UUIDKeeper(uuidKeeper).genUUID(_dappID, _to[i], _toChainIDs[i], _data);
            emit LogC3Call(_dappID, _uuid, _caller, _toChainIDs[i], _to[i], _data, "");
        }
    }

    // called by dapp
    function c3broadcast(uint256 _dappID, string[] calldata _to, string[] calldata _toChainIDs, bytes calldata _data)
        external
        whenNotPaused
    {
        _c3broadcast(_dappID, msg.sender, _to, _toChainIDs, _data);
    }

    function _execute(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal {
        // require(_message.data.length > 0, "C3Caller: empty calldata");
        if (_message.data.length == 0) {
            revert C3Caller_InvalidLength(Uint.Calldata);
        }
        // require(IC3CallerDapp(_message.to).isValidSender(_txSender), "C3Caller: txSender invalid");
        if (!IC3CallerDapp(_message.to).isValidSender(_txSender)) {
            revert C3Caller_OnlyAuthorized(Account.To, Account.Valid);
        }
        // check dappID
        // require(IC3CallerDapp(_message.to).dappID() == _dappID, "C3Caller: dappID dismatch");
        uint256 expectedDAppID = IC3CallerDapp(_message.to).dappID();
        if (expectedDAppID != _dappID) {
            revert C3Caller_InvalidDAppID(expectedDAppID, _dappID);
        }

        //  require(!IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid), "C3Caller: already completed");
        if (IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid)) {
            revert C3Caller_UUIDAlreadyCompleted(_message.uuid);
        }

        context = C3Context({ swapID: _message.uuid, fromChainID: _message.fromChainID, sourceTx: _message.sourceTx });

        (bool success, bytes memory result) = _message.to.call(_message.data);

        context = C3Context({ swapID: "", fromChainID: "", sourceTx: "" });

        emit LogExecCall(
            _dappID, _message.to, _message.uuid, _message.fromChainID, _message.sourceTx, _message.data, success, result
        );

        (bool ok, uint256 rs) = _toUint(result);
        if (success && ok && rs == 1) {
            IC3UUIDKeeper(uuidKeeper).registerUUID(_message.uuid);
        } else {
            emit LogFallbackCall(
                _dappID,
                _message.uuid,
                _message.fallbackTo,
                abi.encodeWithSelector(IC3CallerDapp.c3Fallback.selector, _dappID, _message.data, result),
                result
            );
        }
    }

    // called by mpc network
    function execute(uint256 _dappID, C3EvmMessage calldata _message) external onlyOperator whenNotPaused {
        _execute(_dappID, msg.sender, _message);
    }

    function _c3Fallback(uint256 _dappID, address _txSender, C3EvmMessage calldata _message) internal {
        // require(_message.data.length > 0, "C3Caller: empty calldata");
        if (_message.data.length == 0) {
            revert C3Caller_InvalidLength(Uint.Calldata);
        }
        // require(!IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid), "C3Caller: already completed");
        if (IC3UUIDKeeper(uuidKeeper).isCompleted(_message.uuid)) {
            revert C3Caller_UUIDAlreadyCompleted(_message.uuid);
        }
        // require(IC3CallerDapp(_message.to).isValidSender(_txSender), "C3Caller: txSender invalid");
        if (!IC3CallerDapp(_message.to).isValidSender(_txSender)) {
            revert C3Caller_OnlyAuthorized(Account.To, Account.Valid);
        }

        // require(IC3CallerDapp(_message.to).dappID() == _dappID, "C3Caller: dappID dismatch");
        uint256 expectedDAppID = IC3CallerDapp(_message.to).dappID();
        if (expectedDAppID != _dappID) {
            revert C3Caller_InvalidDAppID(expectedDAppID, _dappID);
        }

        context = C3Context({ swapID: _message.uuid, fromChainID: _message.fromChainID, sourceTx: _message.sourceTx });

        address _target = _message.to;

        bytes memory _result = _target.functionCall(_message.data);

        context = C3Context({ swapID: "", fromChainID: "", sourceTx: "" });

        IC3UUIDKeeper(uuidKeeper).registerUUID(_message.uuid);

        emit LogExecFallback(
            _dappID, _message.to, _message.uuid, _message.fromChainID, _message.sourceTx, _message.data, _result
        );
    }

    // called by mpc network
    function c3Fallback(uint256 _dappID, C3EvmMessage calldata _message) external onlyOperator whenNotPaused {
        _c3Fallback(_dappID, msg.sender, _message);
    }

    function _toUint(bytes memory bs) internal pure returns (bool, uint256) {
        if (bs.length < 32) {
            return (false, 0);
        }
        uint256 x;
        assembly {
            x := mload(add(bs, add(0x20, 0)))
        }
        return (true, x);
    }
}
