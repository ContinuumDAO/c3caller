// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { C3GovClient } from "../gov/C3GovClient.sol";
import { IC3UUIDKeeper } from "./IC3UUIDKeeper.sol";

contract C3UUIDKeeper is IC3UUIDKeeper, C3GovClient, UUPSUpgradeable {
    address public admin;

    mapping(bytes32 => bool) public completedSwapin;
    mapping(bytes32 => uint256) public uuid2Nonce;

    uint256 public currentNonce;

    modifier autoIncreaseSwapoutNonce() {
        currentNonce++;
        _;
    }

    modifier checkCompletion(bytes32 _uuid) {
        // require(!completedSwapin[uuid], "C3SwapIDKeeper: uuid is completed");
        if (completedSwapin[_uuid]) {
            revert C3UUIDKeeper_UUIDAlreadyCompleted(_uuid);
        }
        _;
    }

    function initialize(address _gov) public initializer {
        __C3GovClient_init(_gov);
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
        // require(!this.isUUIDExist(uuid), "uuid already exist");
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

    // TODO test code
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

    function _authorizeUpgrade(address newImplementation) internal override onlyGov { }
}
