// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IC3UUIDKeeper } from "../../uuid/IC3UUIDKeeper.sol";
import { C3GovClientUpgradeable } from "../gov/C3GovClientUpgradeable.sol";

contract C3UUIDKeeperUpgradeable is IC3UUIDKeeper, C3GovClientUpgradeable, UUPSUpgradeable {
    mapping(bytes32 => bool) public completedSwapin;
    mapping(bytes32 => uint256) public uuid2Nonce;

    uint256 public currentNonce;

    modifier autoIncreaseSwapoutNonce() {
        currentNonce++;
        _;
    }

    modifier checkCompletion(bytes32 _uuid) {
        if (completedSwapin[_uuid]) {
            revert C3UUIDKeeper_UUIDAlreadyCompleted(_uuid);
        }
        _;
    }

    function initialize() public initializer {
        __C3GovClient_init(msg.sender);
    }

    function isUUIDExist(bytes32 _uuid) public view returns (bool) {
        return uuid2Nonce[_uuid] != 0;
    }

    function isCompleted(bytes32 _uuid) external view returns (bool) {
        return completedSwapin[_uuid];
    }

    function revokeSwapin(bytes32 _uuid) external onlyGov {
        completedSwapin[_uuid] = false;
    }

    function registerUUID(bytes32 _uuid) external onlyOperator checkCompletion(_uuid) {
        completedSwapin[_uuid] = true;
    }

    function genUUID(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)
        external
        onlyOperator
        autoIncreaseSwapoutNonce
        returns (bytes32 _uuid)
    {
        _uuid = keccak256(
            abi.encode(address(this), msg.sender, block.chainid, _dappID, _to, _toChainID, currentNonce, _data)
        );
        if (isUUIDExist(_uuid)) {
            revert C3UUIDKeeper_UUIDAlreadyExists(_uuid);
        }
        uuid2Nonce[_uuid] = currentNonce;
        return _uuid;
    }

    function calcCallerUUID(
        address _from,
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) public view returns (bytes32) {
        uint256 _nonce = currentNonce + 1;
        return keccak256(abi.encode(address(this), _from, block.chainid, _dappID, _to, _toChainID, _nonce, _data));
    }

    function calcCallerUUIDWithNonce(
        address _from,
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), _from, block.chainid, _dappID, _to, _toChainID, _nonce, _data));
    }

    function calcCallerEncode(
        address _from,
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) public view returns (bytes memory) {
        uint256 _nonce = currentNonce + 1;
        return abi.encode(address(this), _from, block.chainid, _dappID, _to, _toChainID, _nonce, _data);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyGov { }
}
