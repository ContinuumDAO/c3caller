// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IC3GovernDApp} from "../../gov/IC3GovernDApp.sol";
import {IC3CallerDApp} from "../../dapp/IC3CallerDApp.sol";
import {C3CallerDAppUpgradeable} from "../dapp/C3CallerDAppUpgradeable.sol";
import {C3ErrorParam} from "../../utils/C3CallerUtils.sol";

/**
 * @title C3GovernDAppUpgradeable
 * @notice Upgradeable base contract that extends C3CallerDApp for governance functionality in the C3 protocol.
 * This contract provides governance-specific features including delayed governance changes and MPC address validation.
 * It features upgradeable storage using the ERC-7201 storage pattern.
 *
 * The key difference with C3GovClient is that this contract registers a DApp ID. DApp developers can implement it
 * in their C3DApp to allow governance functionality.
 *
 * Key features:
 * - Delayed governance address changes
 * - MPC address validation
 * - Governance-driven cross-chain operations
 * - Fallback mechanism for failed operations
 * - Upgradeable storage using ERC-7201 pattern
 *
 * @dev This contract provides upgradeable governance functionality for DApps
 * @author @potti ContinuumDAO
 */
abstract contract C3GovernDAppUpgradeable is C3CallerDAppUpgradeable, IC3GovernDApp {
    /// @custom:storage-location erc7201:c3caller.storage.C3GovernDApp
    /**
     * @dev Storage struct for C3GovernDApp using ERC-7201 storage pattern
     * @custom:storage-location erc7201:c3caller.storage.C3GovernDApp
     */
    struct C3GovernDAppStorage {
        /// @notice Delay period for governance changes (default: 2 days)
        uint256 delay;
        /// @notice The old governance address
        address _oldGov;
        /// @notice The new governance address
        address _newGov;
        /// @notice The delay between declaring a new governance address and it being confirmed
        uint256 _newGovEffectiveTime;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3GovernDApp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3GovernDAppStorageLocation =
        0x03cfcaef45dcb6fd7af1f4250ec3c5de537d4e89548540d98c1f045c9c010800;

    /**
     * @notice Get the delay between declaring a new governance address and it being confirmed
     * @return The delay in seconds
     */
    function delay() public view virtual returns (uint256) {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        return $.delay;
    }

    /**
     * @notice Get the old governance address (valid until _newGovEffectiveTime)
     * @return The old governance address
     */
    function _oldGov() internal view virtual returns (address) {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        return $._oldGov;
    }

    /**
     * @notice Get the new governance address (valid after _newGovEffectiveTime)
     * @return The new governance address
     */
    function _newGov() internal view virtual returns (address) {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        return $._newGov;
    }

    /**
     * @notice Get the time after which the new governance address is valid
     * @return The new governance address' effective time in seconds
     */
    function _newGovEffectiveTime() internal view virtual returns (uint256) {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        return $._newGovEffectiveTime;
    }

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
     * @notice Internal initializer for the upgradeable C3GovernDApp contract
     * @param _gov The initial governance address
     * @param _c3caller The C3Caller address
     * @param _dappID The DApp ID (obtained from registering with C3DAppManager)
     */
    function __C3GovernDApp_init(address _gov, address _c3caller, uint256 _dappID)
        internal
        onlyInitializing
    {
        __C3CallerDApp_init(_c3caller, _dappID);
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        $.delay = 2 days;
        $._oldGov = _gov;
        $._newGov = _gov;
        $._newGovEffectiveTime = block.timestamp;
    }

    /**
     * @notice Change the governance address. The new governance address will be valid after delay
     * @param newGov_ The new governance address
     * @dev Reverts if the new governance address is zero
     * @dev Only governance or C3Caller can call this function
     */
    function changeGov(address newGov_) external virtual onlyGov {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        if (newGov_ == address(0)) {
            revert C3GovernDApp_IsZeroAddress(C3ErrorParam.Gov);
        }
        $._oldGov = gov();
        $._newGov = newGov_;
        $._newGovEffectiveTime = block.timestamp + $.delay;
        emit LogChangeGov($._oldGov, $._newGov, $._newGovEffectiveTime);
    }

    /**
     * @notice Execute an arbitrary cross-chain operation on a single target
     * @param _to The target address on the destination network
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute
     * @dev Only governance or C3Caller can call this function
     */
    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external virtual onlyGov returns (bytes32) {
        return _c3call(_to, _toChainID, _data);
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
        virtual
        onlyGov
        returns (bytes32[] memory)
    {
        return _c3broadcast(_targets, _toChainIDs, _data);
    }

    /**
     * @notice Set the delay period for governance changes
     * @param _delay The new delay period in seconds
     * @dev Only governance or C3Caller can call this function
     */
    function setDelay(uint256 _delay) external virtual onlyGov {
        C3GovernDAppStorage storage $ = _getC3GovernDAppStorage();
        $.delay = _delay;
    }

    /**
     * @notice Get the current governance address
     * @return The current governance address (new or old based on effective time)
     */
    function gov() public view virtual returns (address) {
        if (block.timestamp >= _newGovEffectiveTime()) {
            return _newGov();
        }
        return _oldGov();
    }

    /**
     * @notice Get the storage struct for C3GovernDApp
     * @return $ The storage struct
     */
    function _getC3GovernDAppStorage() private pure returns (C3GovernDAppStorage storage $) {
        assembly {
            $.slot := C3GovernDAppStorageLocation
        }
    }
}
