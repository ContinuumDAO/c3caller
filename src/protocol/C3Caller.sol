// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IC3Caller.sol";
import "./IUUIDKeeper.sol";
import "./C3GovClient.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract C3Caller is IC3Caller, C3GovClient, Pausable {
    using Address for address;
    using Address for address payable;

    struct C3Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
    }

    C3Context public override context;

    address public uuidKeeper;

    event LogC3Call(
        uint256 indexed dappID,
        bytes32 indexed uuid,
        address caller,
        string toChainID,
        string to,
        bytes data,
        bytes extra
    );

    event LogFallbackCall(
        uint256 indexed dappID,
        bytes32 indexed uuid,
        string to,
        bytes data,
        bytes reasons
    );

    event LogExecCall(
        uint256 indexed dappID,
        address indexed to,
        bytes32 indexed uuid,
        string fromChainID,
        string sourceTx,
        bytes data,
        bool success,
        bytes reason
    );

    event LogExecFallback(
        uint256 indexed dappID,
        address indexed to,
        bytes32 indexed uuid,
        string fromChainID,
        string sourceTx,
        bytes data,
        bytes reason
    );

    constructor(address _swapIDKeeper) {
        initGov(msg.sender);
        uuidKeeper = _swapIDKeeper;
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    function c3call(
        uint256 _dappID,
        address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external override whenNotPaused {
        require(_dappID > 0, "C3Caller: empty dappID");
        require(bytes(_to).length > 0, "C3Caller: empty _to");
        require(bytes(_toChainID).length > 0, "C3Caller: empty toChainID");
        require(_data.length > 0, "C3Caller: empty calldata");
        bytes32 _uuid = IUUIDKeeper(uuidKeeper).genUUID(
            _dappID,
            _to,
            _toChainID,
            _data
        );
        emit LogC3Call(_dappID, _uuid, _caller, _toChainID, _to, _data, _extra);
    }

    function c3broadcast(
        uint256 _dappID,
        address _caller,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) external override whenNotPaused {
        require(_dappID > 0, "C3Caller: empty dappID");
        require(_to.length > 0, "C3Caller: empty _to");
        require(_toChainIDs.length > 0, "C3Caller: empty toChainID");
        require(_data.length > 0, "C3Caller: empty calldata");
        require(
            _data.length == _toChainIDs.length,
            "C3Caller: calldata length dismatch"
        );

        for (uint256 i = 0; i < _toChainIDs.length; i++) {
            bytes32 _uuid = IUUIDKeeper(uuidKeeper).genUUID(
                _dappID,
                _to[i],
                _toChainIDs[i],
                _data
            );
            emit LogC3Call(
                _dappID,
                _uuid,
                _caller,
                _toChainIDs[i],
                _to[i],
                _data,
                ""
            );
        }
    }

    function execute(
        uint256 _dappID,
        address _txSender,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) external override onlyOperator whenNotPaused {
        require(_message.data.length > 0, "C3Caller: empty calldata");
        require(
            IC3Dapp(_message.to).isVaildSender(_txSender),
            "C3Caller: txSender invalid"
        );
        // check dappID
        require(
            IC3Dapp(_message.to).dappID() == _dappID,
            "C3Caller: dappID dismatch"
        );

        require(
            !IUUIDKeeper(uuidKeeper).isCompleted(_message.uuid),
            "C3Caller: already completed"
        );

        context = C3Context({
            swapID: _message.uuid,
            fromChainID: _message.fromChainID,
            sourceTx: _message.sourceTx
        });

        (bool success, bytes memory result) = _message.to.call(_message.data);

        context = C3Context({swapID: "", fromChainID: "", sourceTx: ""});

        emit LogExecCall(
            _dappID,
            _message.to,
            _message.uuid,
            _message.fromChainID,
            _message.sourceTx,
            _message.data,
            success,
            result
        );
        (bool ok, uint rs) = toUint(result);
        if (success && ok && rs == 1) {
            IUUIDKeeper(uuidKeeper).registerUUID(_message.uuid);
        } else {
            emit LogFallbackCall(
                _dappID,
                _message.uuid,
                _message.fallbackTo,
                abi.encodeWithSelector(
                    IC3Dapp.c3Fallback.selector,
                    _dappID,
                    _message.data,
                    result
                ),
                result
            );
        }
    }

    function c3Fallback(
        uint256 _dappID,
        address _txSender,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) external override onlyOperator whenNotPaused {
        require(_message.data.length > 0, "C3Caller: empty calldata");
        require(
            !IUUIDKeeper(uuidKeeper).isCompleted(_message.uuid),
            "C3Caller: already completed"
        );
        require(
            IC3Dapp(_message.to).isVaildSender(_txSender),
            "C3Caller: txSender invalid"
        );

        require(
            IC3Dapp(_message.to).dappID() == _dappID,
            "C3Caller: dappID dismatch"
        );

        context = C3Context({
            swapID: _message.uuid,
            fromChainID: _message.fromChainID,
            sourceTx: _message.sourceTx
        });

        address _target = _message.to;

        bytes memory _result = _target.functionCall(
            _message.data,
            "C3Caller: c3Fallback failed"
        );

        context = C3Context({swapID: "", fromChainID: "", sourceTx: ""});

        IUUIDKeeper(uuidKeeper).registerUUID(_message.uuid);

        emit LogExecFallback(
            _dappID,
            _message.to,
            _message.uuid,
            _message.fromChainID,
            _message.sourceTx,
            _message.data,
            _result
        );
    }

    function toUint(bytes memory bs) internal pure returns (bool, uint) {
        if (bs.length < 32) {
            return (false, 0);
        }
        uint x;
        assembly {
            x := mload(add(bs, add(0x20, 0)))
        }
        return (true, x);
    }
}
