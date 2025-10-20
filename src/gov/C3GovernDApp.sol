// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {C3CallerDApp} from "../dapp/C3CallerDApp.sol";
import {IC3CallerDApp} from "../dapp/IC3CallerDApp.sol";

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {IC3GovernDApp} from "./IC3GovernDApp.sol";

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
    using Strings for *;
    using Address for address;

    /// @notice Delay period for governance changes (default: 2 days)
    uint256 public delay;

    /// @notice The old governance address
    address internal _oldGov;

    /// @notice The new governance address
    address internal _newGov;

    /// @notice The delay between declaring a new governance address and it being confirmed
    uint256 internal _newGovEffectiveTime;

    /// @notice Mapping of MPC addresses to their validity
    mapping(address => bool) public txSenders;

    /// @notice Array of all txSender addresses
    address[] public senders;

    /**
     * @notice Modifier to restrict access to governance or C3Caller
     * @dev Reverts if the caller is neither governance address nor C3Caller
     */
    modifier onlyGov() {
        if (msg.sender != gov() && msg.sender != c3caller) {
            revert C3GovernDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrC3Caller);
        }
        _;
    }

    /**
     * @param _gov The initial governance address
     * @param _c3caller The C3Caller address
     * @param _txSender The initial valid MPC address
     * @param _dappID The DApp ID (obtained from registering with C3DAppManager)
     */
    constructor(address _gov, address _c3caller, address _txSender, uint256 _dappID) C3CallerDApp(_c3caller, _dappID) {
        delay = 2 days;
        _oldGov = _gov;
        _newGov = _gov;
        _newGovEffectiveTime = block.timestamp;
        txSenders[_txSender] = true;
        senders.push(_txSender);
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
        emit LogChangeGov(_oldGov, _newGov, _newGovEffectiveTime, block.chainid);
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
     * @notice Add an MPC address that can call functions that should be targeted by C3Caller execute
     * @param _txSender The MPC address to add
     * @dev Only governance or C3Caller can call this function
     */
    function addTxSender(address _txSender) external onlyGov {
        if (!txSenders[_txSender]) {
            txSenders[_txSender] = true;
            senders.push(_txSender);
            emit LogTxSender(_txSender, true);
        }
    }

    /**
     * @notice Disable an MPC address, which will no longer be able to call functions targeted by C3Caller execute
     * @param _txSender The MPC address to disable
     * @dev Only governance or C3Caller can call this function
     */
    function disableTxSender(address _txSender) external onlyGov {
        if (txSenders[_txSender]) {
            txSenders[_txSender] = false;
            uint256 senderCount = senders.length;
            for (uint256 i = 0; i < senderCount; i++) {
                if (senders[i] == _txSender) {
                    senders[i] = senders[senderCount - 1];
                    senders.pop();
                    break;
                }
            }
            emit LogTxSender(_txSender, false);
        }
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
     * @notice Get all txSender addresses
     * @return Array of all txSender addresses
     */
    function getAllTxSenders() external view returns (address[] memory) {
        return senders;
    }

    /**
     * @notice Check if an address is a valid MPC address executor for this DApp
     * @param _txSender The address to check
     * @return True if the address is a valid sender, false otherwise
     */
    function isValidSender(address _txSender) external view override(IC3CallerDApp, C3CallerDApp) returns (bool) {
        return txSenders[_txSender];
    }
}
