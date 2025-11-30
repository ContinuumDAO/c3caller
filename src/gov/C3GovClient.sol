// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {IC3GovClient} from "./IC3GovClient.sol";

/**
 * @title C3GovClient
 * @notice Base contract for governance client functionality in the C3 protocol.
 * This contract provides governance management capabilities that can be inherited by other contracts in the C3
 * ecosystem. The key difference between this contract and C3GovernDApp is that this contract does not
 * contain a DApp ID, as it is designed to provide governance functionality without cross-chain functionality.
 *
 * Contracts that implement this contract are C3Caller, C3UUIDKeeper and C3DAppManager. These are protocol contracts and
 * therefore do not need to be a C3GovernDApp.
 *
 * Key features:
 * - Governance address management with confirmation from the new address required (double-lock)
 * - C3Caller address management
 * - Access control modifiers for governance and C3Caller
 * - Event emission for governance changes and C3Caller address changes
 *
 * @dev This contract provides the foundation for governance functionality
 * @author @potti ContinuumDAO
 */
contract C3GovClient is IC3GovClient, Pausable {
    /// @notice The C3Caller contract address
    address public c3caller;

    /// @notice The current governance address
    address public gov;

    /// @notice The pending governance address (for two-step governance changes)
    address public pendingGov;

    /**
     * @notice Modifier to restrict access to governance only
     * @dev Reverts if the caller is not the governance address
     */
    modifier onlyGov() {
        if (msg.sender != gov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Gov);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to C3Caller only
     * @dev Reverts if the caller is not the C3Caller address
     */
    modifier onlyC3Caller() {
        if (msg.sender != c3caller) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.C3Caller);
        }
        _;
    }

    /**
     * @param _gov The initial governance address
     */
    constructor(address _gov) {
        gov = _gov;
        emit ApplyGov(address(0), _gov);
    }

    /**
     * @notice Change the C3Caller address
     * @param _c3caller The new C3Caller address
     * @dev Only governance can call this
     */
    function setC3Caller(address _c3caller) external onlyGov {
        address oldC3Caller = c3caller;
        c3caller = _c3caller;
        emit SetC3Caller(oldC3Caller, _c3caller);
    }

    /**
     * @notice Change the governance address (two-step process)
     * @param _gov The new governance address
     * @dev Only the current governance address can call this function
     */
    function changeGov(address _gov) external onlyGov {
        pendingGov = _gov;
        emit ChangeGov(gov, _gov);
    }

    /**
     * @notice Apply the pending governance change
     * @dev Reverts if there is no pending governance address
     * @dev Anyone can call this function to finalize the governance change
     */
    function applyGov() external {
        if (msg.sender != pendingGov) {
            revert C3GovClient_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.PendingGov);
        }
        address oldGov = gov;
        address newGov = pendingGov;
        gov = pendingGov;
        pendingGov = address(0);
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
}
