// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {IC3GovClient} from "../../gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../utils/C3CallerUtils.sol";

/**
 * @title C3GovClientUpgradeable
 * @notice Upgradeable base contract for governance client functionality in the C3 protocol.
 * This contract provides governance and operator management capabilities that can be inherited by other contracts
 * in the C3 ecosystem. The key difference between this contract and C3GovernDApp is that this contract does not
 * contain a DApp ID, as it is designed to provide governance functionality without cross-chain functionality.
 * It features upgradeable storage using the ERC-7201 storage pattern.
 *
 * Examples of contracts that implement this contract are C3Caller, C3UUIDKeeper and C3DAppManager. These are protocol
 * contracts and therefore do not need to be a C3GovernDApp.
 *
 * Key features:
 * - Governance address management with pending changes
 * - Operator management (add/remove operators)
 * - Access control modifiers for governance and operators
 * - Event emission for governance changes
 * - Upgradeable storage using ERC-7201 pattern
 *
 * @dev This contract provides the foundation for upgradeable governance functionality
 * @author @potti ContinuumDAO
 */
contract C3GovClientUpgradeable is IC3GovClient, Initializable, PausableUpgradeable {
    /**
     * @dev Storage struct for C3GovClient using ERC-7201 storage pattern
     * @custom:storage-location erc7201:c3caller.storage.C3GovClient
     */
    struct C3GovClientStorage {
        /// @notice The C3Caller contract address
        address c3caller;
        /// @notice The current governance address
        address gov;
        /// @notice The pending governance address (for two-step governance changes)
        address pendingGov;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3GovClient")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3GovClientStorageLocation =
        0xfc30bbdfb847b0ba1d1dd9d15321eef3badc6d5d43505a7d5c3da71b05087100;

    /**
     * @notice Get the c3caller address
     * @return The c3caller address
     */
    function c3caller() public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.c3caller;
    }

    /**
     * @notice Get the current governance address
     * @return The current governance address
     */
    function gov() public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.gov;
    }

    /**
     * @notice Get the pending governance address
     * @return The pending governance address
     */
    function pendingGov() public view returns (address) {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        return $.pendingGov;
    }

    /**
     * @notice Modifier to restrict access to governance only
     * @dev Reverts if the caller is not the governor
     */
    modifier onlyGov() {
        if (msg.sender != gov()) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Gov);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to C3Caller only
     * @dev Reverts if the caller is not the C3Caller address
     */
    modifier onlyC3Caller() {
        if (msg.sender != c3caller()) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.C3Caller);
        }
        _;
    }

    /**
     * @notice Internal initializer for the upgradeable C3GovClient contract
     * @param _gov The initial governance address
     */
    function __C3GovClient_init(address _gov) internal onlyInitializing {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        $.gov = _gov;
        emit ApplyGov(address(0), _gov);
    }

    /**
     * @notice Change the C3Caller address
     * @param _c3caller The new C3Caller address
     * @dev Only governance can call this
     */
    function setC3Caller(address _c3caller) external onlyGov {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        address oldC3Caller = $.c3caller;
        $.c3caller = _c3caller;
        emit SetC3Caller(oldC3Caller, _c3caller);
    }

    /**
     * @notice Change the governance address (two-step process)
     * @param _gov The new governance address
     * @dev Only the current governance address can call this function
     */
    function changeGov(address _gov) external onlyGov {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        $.pendingGov = _gov;
        emit ChangeGov($.gov, _gov);
    }

    /**
     * @notice Apply the pending governance change
     * @dev Reverts if there is no pending governance address
     * @dev Anyone can call this function to finalize the governance change
     */
    function applyGov() external {
        C3GovClientStorage storage $ = _getC3GovClientStorage();
        if (msg.sender != $.pendingGov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.PendingGov);
        }
        address oldGov = $.gov;
        address newGov = $.pendingGov;
        $.gov = $.pendingGov;
        $.pendingGov = address(0);
        emit ApplyGov(oldGov, newGov);
    }

    /**
     * @notice Pause the contract (governance only)
     * @dev Only the governance address can call this function
     */
    function pause() public onlyGov {
        _pause();
    }

    /**
     * @notice Unpause the contract (governance only)
     * @dev Only the governance address can call this function
     */
    function unpause() public onlyGov {
        _unpause();
    }

    /**
     * @notice Get the storage struct for C3GovClient
     * @return $ The storage struct
     */
    function _getC3GovClientStorage() private pure returns (C3GovClientStorage storage $) {
        assembly {
            $.slot := C3GovClientStorageLocation
        }
    }
}
