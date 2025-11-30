// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {C3GovClient} from "../gov/C3GovClient.sol";
import {IC3UUIDKeeper} from "./IC3UUIDKeeper.sol";

/**
 * @title C3UUIDKeeper
 * @notice Contract for managing Universally Unique Identifiers (UUIDs) in the C3 protocol.
 * This contract is responsible for generating, tracking, and validating UUIDs for cross-chain operations to prevent
 * replay attacks and ensure uniqueness.
 *
 * Key features:
 * - UUID generation with nonce-based uniqueness
 * - UUID completion tracking
 * - UUID revocation capabilities
 * - Utilities to calculate UUID before, as OR after it happens
 *
 * @dev This contract is critical for cross-chain security and uniqueness
 * @author @potti ContinuumDAO
 */
contract C3UUIDKeeper is IC3UUIDKeeper, C3GovClient {
    /// @notice Latest used nonce for UUID generation - next UUID will use `currentNonce` +1
    uint256 public currentNonce;

    /// @notice Mapping of UUID to completion status
    mapping(bytes32 => bool) public completedSwapIn;

    /// @notice Mapping of UUID to its associated nonce
    mapping(bytes32 => uint256) public uuid2Nonce;

    /**
     * @notice Modifier to automatically increment the swapout nonce
     * @dev Increments the current nonce before executing the function
     */
    modifier autoIncreaseSwapoutNonce() {
        currentNonce++;
        _;
    }

    /**
     * @notice Modifier to check if a UUID has already been completed
     * @param _uuid The UUID to check
     * @dev Reverts if the UUID has already been completed
     */
    modifier checkCompletion(bytes32 _uuid) {
        if (completedSwapIn[_uuid]) {
            revert C3UUIDKeeper_UUIDAlreadyCompleted(_uuid);
        }
        _;
    }

    /**
     * @notice Initializes the contract with the deployer as governance address
     */
    constructor() C3GovClient(msg.sender) {}

    /**
     * @notice Generate a new UUID for cross-chain operations and increment the nonce
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain ID
     * @param _data The calldata for the cross-chain operation
     * @return _uuid The generated UUID
     * @dev Only C3Caller address can call this function
     */
    function genUUID(uint256 _dappID, string calldata _to, string calldata _toChainID, bytes calldata _data)
        external
        onlyC3Caller
        autoIncreaseSwapoutNonce
        returns (bytes32 _uuid)
    {
        _uuid = keccak256(
            abi.encode(address(this), msg.sender, block.chainid, _dappID, _to, _toChainID, currentNonce, _data)
        );
        uuid2Nonce[_uuid] = currentNonce;

        emit UUIDGenerated(_uuid, _dappID, msg.sender, _to, _toChainID, currentNonce, _data);
        return _uuid;
    }

    /**
     * @notice Register a UUID as completed
     * @param _uuid The UUID to register as completed
     * @param _dappID The DApp identifier associated with the UUID
     * @dev Only C3Caller address can call this function
     */
    function registerUUID(bytes32 _uuid, uint256 _dappID) external onlyC3Caller checkCompletion(_uuid) {
        completedSwapIn[_uuid] = true;
        emit UUIDCompleted(_uuid, _dappID, msg.sender);
    }

    /**
     * @notice Revoke a completed UUID (governance only)
     * @param _uuid The UUID to revoke
     * @param _dappID The DApp identifier associated with the UUID
     * @dev Only the governance address can call this function
     */
    function revokeSwapIn(bytes32 _uuid, uint256 _dappID) external onlyGov {
        completedSwapIn[_uuid] = false;
        emit UUIDRevoked(_uuid, _dappID, msg.sender);
    }

    /**
     * @notice Check if a UUID has been completed
     * @param _uuid The UUID to check
     * @return True if the UUID has been completed, false otherwise
     */
    function isCompleted(bytes32 _uuid) external view returns (bool) {
        return completedSwapIn[_uuid];
    }

    /**
     * @notice Check if a UUID exists in the system
     * @param _uuid The UUID to check
     * @return True if the UUID exists, false otherwise
     */
    function doesUUIDExist(bytes32 _uuid) public view returns (bool) {
        return uuid2Nonce[_uuid] != 0;
    }

    /**
     * @notice Calculate the UUID for a given payload without incrementing the nonce
     * @param _from The address of the caller (this is always the C3Caller contract)
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain ID
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
        return calcCallerUUIDWithNonce(_from, _dappID, _to, _toChainID, _data, _nonce);
    }

    /**
     * @notice Calculate the UUID for a given payload with a specific nonce, without incrementing it
     * @param _from The address of the caller (this is always the C3Caller contract)
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain ID
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
     * @notice Calculate the encoded data for a given payload with a specific nonce, without incrementing it
     * @param _from The address of the caller
     * @param _dappID The DApp identifier
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata for the cross-chain operation
     * @return The encoded data for the UUID
     * @dev This function returns the input to keccak256 that would produce the corresponding UUID
     */
    function calcCallerUUIDEncodingWithNonce(
        address _from,
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data,
        uint256 _nonce
    ) public view returns (bytes memory) {
        return abi.encode(address(this), _from, block.chainid, _dappID, _to, _toChainID, _nonce, _data);
    }
}
