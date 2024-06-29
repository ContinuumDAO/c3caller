// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IC3Caller.sol";
import "./C3GovClient.sol";

contract C3CallerProxy is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    C3GovClient,
    IC3CallerProxy
{
    address public c3caller;

    function initialize(address _c3caller) public initializer {
        initGov(msg.sender);
        c3caller = _c3caller;
        __UUPSUpgradeable_init();
        __Ownable_init();
        transferOwnership(msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOperator {}

    function isExecutor(address sender) external view override returns (bool) {
        return isOperator[sender];
    }

    function isCaller(address sender) external view override returns (bool) {
        return sender == c3caller;
    }

    function context()
        external
        view
        override
        returns (
            bytes32 swapID,
            string memory fromChainID,
            string memory sourceTx
        )
    {
        return IC3Caller(c3caller).context();
    }

    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external override {
        IC3Caller(c3caller).c3call(
            _dappID,
            msg.sender,
            _to,
            _toChainID,
            _data,
            ""
        );
    }

    // called by dapp
    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        bytes memory _extra
    ) external override {
        IC3Caller(c3caller).c3call(
            _dappID,
            msg.sender,
            _to,
            _toChainID,
            _data,
            _extra
        );
    }
    // called by dapp
    function c3broadcast(
        uint256 _dappID,
        string[] calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) external override {
        IC3Caller(c3caller).c3broadcast(
            _dappID,
            msg.sender,
            _to,
            _toChainIDs,
            _data
        );
    }

    // called by mpc network
    function execute(
        uint256 _dappID,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) external override onlyOperator {
        IC3Caller(c3caller).execute(_dappID, msg.sender, _message);
    }

    // called by mpc network
    function c3Fallback(
        uint256 _dappID,
        C3CallerStructLib.C3EvmMessage calldata _message
    ) external override onlyOperator {
        IC3Caller(c3caller).c3Fallback(_dappID, msg.sender, _message);
    }
}
