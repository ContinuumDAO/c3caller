// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IC3UUIDKeeper } from "../../uuid/IC3UUIDKeeper.sol";
import { C3GovClientUpgradeable } from "../gov/C3GovClientUpgradeable.sol";

/**
 * @title C3UUIDKeeperUpgradeable
 * @dev Upgradeable contract for managing unique identifiers (UUIDs) in the C3 protocol.
 * This contract provides the same functionality as C3UUIDKeeper but with upgradeable capabilities
 * using the UUPS (Universal Upgradeable Proxy Standard) pattern.
 * 
 * Key features:
 * - UUID generation with nonce-based uniqueness
 * - UUID completion tracking
 * - UUID revocation capabilities
 * - Cross-chain UUID calculation utilities
 * - Upgradeable functionality via UUPS pattern
 * 
 * @notice This contract is the upgradeable version of the UUID management system
 * @author @potti ContinuumDAO
 */
contract C3UUIDKeeperUpgradeable is IC3UUIDKeeper, C3GovClientUpgradeable, UUPSUpgradeable {
    /// @notice Mapping of UUID to completion status
    mapping(bytes32 => bool) public completedSwapin;
    
    /// @notice Mapping of UUID to its associated nonce
    mapping(bytes32 => uint256) public uuid2Nonce;

    /// @notice Current nonce for UUID generation
    uint256 public currentNonce;

    /**
     * @dev Modifier to automatically increase the swapout nonce
     * @notice Increments the current nonce before executing the function
     */
    modifier autoIncreaseSwapoutNonce() {
        currentNonce++;
        _;
    }

    /**
     * @dev Modifier to check if a UUID has already been completed
     * @param _uuid The UUID to check
     * @notice Reverts if the UUID has already been completed
     */
    modifier checkCompletion(bytes32 _uuid) {
        if (completedSwapin[_uuid]) {
            revert C3UUIDKeeper_UUIDAlreadyCompleted(_uuid);
        }
        _;
    }

    /**
     * @notice Initialize the upgradeable C3UUIDKeeper contract
     * @dev This function can only be called once during deployment
     */
    function initialize() public initializer {
        // BUG: #44 Missing __UUPSUpgradeable_init() in C3UUIDKeeperUpgradeable:initialize()
        // PASSED:
        __UUPSUpgradeable_init();
        __C3GovClient_init(msg.sender);
    }

    /**
     * @notice Check if a UUID exists in the system
     * @param _uuid The UUID to check
     * @return True if the UUID exists, false otherwise
     */
    function isUUIDExist(bytes32 _uuid) public view returns (bool) {
        return uuid2Nonce[_uuid] != 0;
    }

    /**
     * @notice Check if a UUID has been completed
     * @param _uuid The UUID to check
     * @return True if the UUID has been completed, false otherwise
     */
    function isCompleted(bytes32 _uuid) external view returns (bool) {
        return completedSwapin[_uuid];
    }

    /**
     * @notice Revoke a completed UUID (governance only)
     * @dev Only the governor can call this function
     * @param _uuid The UUID to revoke
     */
    function revokeSwapin(bytes32 _uuid) external onlyGov {
        completedSwapin[_uuid] = false;
    }

    /**
     * @notice Register a UUID as completed (operator only)
     * @dev Only operators can call this function
     * @param _uuid The UUID to register as completed
     */
    function registerUUID(bytes32 _uuid) external onlyOperator checkCompletion(_uuid) {
        completedSwapin[_uuid] = true;
    }

    /**
     * @notice Generate a new UUID for cross-chain operations
     * @dev Only operators can call this function
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata for the cross-chain operation
     * @return _uuid The generated UUID
     */
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

    /**
     * @notice Calculate a UUID for a caller without generating it
     * @param _from The address of the caller
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata for the cross-chain operation
     * @return The calculated UUID
     */
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

    /**
     * @notice Calculate a UUID with a specific nonce
     * @param _from The address of the caller
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata for the cross-chain operation
     * @param _nonce The specific nonce to use
     * @return The calculated UUID
     */
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

    /**
     * @notice Calculate the encoded data for a UUID without generating it
     * @param _from The address of the caller
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata for the cross-chain operation
     * @return The encoded data for the UUID
     */
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

    /**
     * @dev Internal function to authorize upgrades
     * @param newImplementation The new implementation address
     * @notice Only governance can authorize upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyGov { }
}
