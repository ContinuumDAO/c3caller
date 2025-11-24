// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3GovernDApp} from "./IC3GovernDApp.sol";
import {IC3CallerDApp} from "../dapp/IC3CallerDApp.sol";
import {C3CallerDApp} from "../dapp/C3CallerDApp.sol";
import {C3ErrorParam} from "../utils/C3CallerUtils.sol";

/**
 * @title C3GovernDApp
 * @notice Base contract that extends C3CallerDApp for governance functionality in the C3 protocol.
 * This contract provides governance-specific features including delayed governance changes and MPC address validation.
 *
 * The key difference with C3GovClient is that this contract registers a DApp ID. DApp developers can implement it
 * in their C3DApp to allow governance functionality.
 *
 * Key features:
 * - Delayed governance address changes
 * - MPC address validation
 * - Governance-driven cross-chain operations
 * - Fallback mechanism for failed operations
 *
 * @dev This contract provides governance functionality for DApps
 * @author @potti ContinuumDAO
 */
abstract contract C3GovernDApp is C3CallerDApp, IC3GovernDApp {
    /// @notice Delay period for governance changes (default: 2 days)
    uint256 public delay;

    /// @notice The old governance address
    address internal _oldGov;

    /// @notice The new governance address
    address internal _newGov;

    /// @notice The delay between declaring a new governance address and it being confirmed
    uint256 internal _newGovEffectiveTime;

    /**
     * @notice Modifier to restrict access to governance address
     * @dev Reverts if the caller is not governance address
     */
    modifier onlyGov() {
        if (msg.sender != gov()) {
            revert C3GovernDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.Gov);
        }
        _;
    }

    /**
     * @param _gov The initial governance address
     * @param _c3caller The C3Caller address
     * @param _dappID The DApp ID (obtained from registering with C3DAppManager)
     */
    constructor(address _gov, address _c3caller, uint256 _dappID) C3CallerDApp(_c3caller, _dappID) {
        delay = 2 days;
        _oldGov = _gov;
        _newGov = _gov;
        _newGovEffectiveTime = block.timestamp;
    }

    /**
     * @notice Change the governance address. The new governance address will be valid after delay
     * @param newGov_ The new governance address
     * @dev Reverts if the new governance address is zero
     * @dev Only governance or C3Caller can call this function
     */
    function changeGov(address newGov_) external onlyGov {
        if (newGov_ == address(0)) {
            revert C3GovernDApp_IsZeroAddress(C3ErrorParam.Gov);
        }
        _oldGov = gov();
        _newGov = newGov_;
        _newGovEffectiveTime = block.timestamp + delay;
        emit LogChangeGov(_oldGov, _newGov, _newGovEffectiveTime);
    }

    /**
     * @notice Execute an arbitrary cross-chain operation on a single target
     * @param _to The target address on the destination network
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute
     * @dev Only governance or C3Caller can call this function
     */
    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external onlyGov {
        _c3call(_to, _toChainID, _data);
    }

    /**
     * @notice Execute an arbitrary cross-chain operation on multiple targets and multiple networks
     * @param _targets Array of target addresses on destination networks
     * @param _toChainIDs Array of destination chain IDs
     * @param _data The calldata to execute
     * @dev Only governance or C3Caller can call this function
     */
    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data)
        external
        onlyGov
    {
        _c3broadcast(_targets, _toChainIDs, _data);
    }

    /**
     * @notice Set the delay period for governance changes
     * @param _delay The new delay period in seconds
     * @dev Only governance or C3Caller can call this function
     */
    function setDelay(uint256 _delay) external onlyGov {
        delay = _delay;
    }

    /**
     * @notice Get the current governance address
     * @return The current governance address (new or old based on effective time)
     */
    function gov() public view returns (address) {
        if (block.timestamp >= _newGovEffectiveTime) {
            return _newGov;
        }
        return _oldGov;
    }
}
