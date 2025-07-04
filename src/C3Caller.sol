// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IC3Caller, IC3Dapp, C3CallerStructLib} from  "./IC3Caller.sol";
import {IUUIDKeeper} from "./IUUIDKeeper.sol";
import {C3GovClientUpgradeable} from "./C3GovClientUpgradeable.sol";

contract C3Caller is
    IC3Caller,
    UUPSUpgradeable,
    C3GovClientUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using Address for address;
    using Address for address payable;

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

    struct C3Context {
        bytes32 swapID;
        string fromChainID;
        string sourceTx;
    }

    C3Context public context;
    // address public c3caller;
    address public uuidKeeper;

    function initialize(address _swapIDKeeper) public initializer {
        __UUPSUpgradeable_init();
        __C3GovClient_init(msg.sender);
        __Ownable_init(msg.sender);
        __Pausable_init();
        uuidKeeper = _swapIDKeeper;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOperator {}

    function isExecutor(address sender) external view returns (bool) {
        return isOperator(sender);
    }

    function c3caller() public view returns (address) {
        return address(this);
    }

    function isCaller(address sender) external view returns (bool) {
        // return sender == c3caller;
        return sender == address(this);
    }

    function _c3call(
        uint256 _dappID,
        address _caller,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) internal {
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
    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external whenNotPaused {
        _c3call(_dappID, msg.sender, _to, _toChainID, _data, "");
    }

    function _c3broadcast(
        uint256 _dappID,
        address _caller,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) internal {
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

    // called by dapp
    function c3broadcast(
        uint256 _dappID,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) external whenNotPaused {
        _c3broadcast(_dappID, msg.sender, _to, _toChainIDs, _data);
    }

    function _execute(
        uint256 _dappID,
        address _txSender,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) internal {
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

        (bool ok, uint rs) = _toUint(result);
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

    // called by mpc network
    function execute(
        uint256 _dappID,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) external onlyOperator whenNotPaused {
        _execute(_dappID, msg.sender, _message);
    }

    function _c3Fallback(
        uint256 _dappID,
        address _txSender,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) internal {
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

        bytes memory _result = _target.functionCall(_message.data);

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

    // called by mpc network
    function c3Fallback(
        uint256 _dappID,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) external onlyOperator whenNotPaused {
        _c3Fallback(_dappID, msg.sender, _message);
    }

    function _toUint(bytes memory bs) internal pure returns (bool, uint) {
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
