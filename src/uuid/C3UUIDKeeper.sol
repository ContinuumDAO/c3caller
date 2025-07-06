// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IC3UUIDKeeper } from "./IC3UUIDKeeper.sol";
import { C3GovClient } from "../gov/C3GovClient.sol";

contract C3UUIDKeeperUpgradeable is IC3UUIDKeeper, C3GovClient, UUPSUpgradeable {
    address public admin;

    mapping (bytes32 => bool) public completedSwapin;
    mapping (bytes32 => uint256) public uuid2Nonce;

    uint256 public currentNonce;

    modifier autoIncreaseSwapoutNonce() {
        currentNonce++;
        _;
    }

    modifier checkCompletion(bytes32 uuid) {
        require(!completedSwapin[uuid], "C3SwapIDKeeper: uuid is completed");
        _;
    }

    function initialize(address _gov) public initializer {
        __C3GovClient_init(_gov);
    }

    function isUUIDExist(bytes32 uuid) external view returns (bool) {
        return uuid2Nonce[uuid] != 0;
    }

    function isCompleted(bytes32 uuid) external view returns (bool) {
        return completedSwapin[uuid];
    }
    // TODO change name

    function revokeSwapin(bytes32 uuid) external onlyGov {
        completedSwapin[uuid] = false;
    }

    function registerUUID(bytes32 uuid) external onlyOperator checkCompletion(uuid) {
        completedSwapin[uuid] = true;
    }

    function genUUID(uint256 dappID, string calldata to, string calldata toChainID, bytes calldata data)
        external
        onlyOperator
        autoIncreaseSwapoutNonce
        returns (bytes32 uuid)
    {
        uuid =
            keccak256(abi.encode(address(this), msg.sender, block.chainid, dappID, to, toChainID, currentNonce, data));
        require(!this.isUUIDExist(uuid), "uuid already exist");
        uuid2Nonce[uuid] = currentNonce;
        return uuid;
    }

    function calcCallerUUID(
        address from,
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) public view returns (bytes32) {
        uint256 nonce = currentNonce + 1;
        return keccak256(abi.encode(address(this), from, block.chainid, dappID, to, toChainID, nonce, data));
    }

    // TODO test code
    function calcCallerEncode(
        address from,
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) public view returns (bytes memory) {
        uint256 nonce = currentNonce + 1;
        return abi.encode(address(this), from, block.chainid, dappID, to, toChainID, nonce, data);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyGov {}
}
