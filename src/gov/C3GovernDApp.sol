// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3CallerDApp } from "../dapp/C3CallerDApp.sol";
import { IC3CallerDApp } from "../dapp/IC3CallerDApp.sol";

import { C3ErrorParam } from "../utils/C3CallerUtils.sol";
import { IC3GovernDApp } from "./IC3GovernDApp.sol";

/**
 * @title C3GovernDApp
 * @dev Abstract contract for governance DApp functionality in the C3 protocol.
 * This contract extends C3CallerDApp to provide governance-specific features
 * including delayed governance changes and transaction sender management.
 * 
 * Key features:
 * - Delayed governance address changes
 * - Transaction sender management
 * - Governance-driven cross-chain operations
 * - Fallback mechanism for failed operations
 * 
 * @notice This contract provides governance functionality for DApps
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
    
    /// @notice The effective time for the new governance address
    uint256 internal _newGovEffectiveTime;
    
    /// @notice Mapping of transaction sender addresses to their validity
    mapping(address => bool) internal _txSenders;

    /**
     * @dev Constructor for C3GovernDApp
     * @param _gov The initial governance address
     * @param _c3callerProxy The C3Caller proxy address
     * @param _txSender The initial transaction sender address
     * @param _dappID The DApp identifier
     */
    constructor(address _gov, address _c3callerProxy, address _txSender, uint256 _dappID)
        C3CallerDApp(_c3callerProxy, _dappID)
    {
        delay = 2 days;
        _oldGov = _gov;
        _newGov = _gov;
        _newGovEffectiveTime = block.timestamp;
        _txSenders[_txSender] = true;
    }

    /**
     * @dev Modifier to restrict access to governance or C3Caller
     * @notice Reverts if the caller is neither governor nor C3Caller
     */
    modifier onlyGov() {
        if (msg.sender != gov() && !_isCaller(msg.sender)) {
            revert C3GovernDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.GovOrC3Caller);
        }
        _;
    }

    /**
     * @notice Check if an address is a valid transaction sender
     * @param sender The address to check
     * @return True if the address is a valid transaction sender
     */
    function txSenders(address sender) public view returns (bool) {
        return _txSenders[sender];
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
     * @notice Change the governance address with delay
     * @dev Only governance or C3Caller can call this function
     * @param newGov_ The new governance address
     * @notice Reverts if the new governance address is zero
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
     * @dev Only governance or C3Caller can call this function
     * @param _delay The new delay period in seconds
     */
    function setDelay(uint256 _delay) external onlyGov {
        delay = _delay;
    }

    /**
     * @notice Add a transaction sender address
     * @dev Only governance or C3Caller can call this function
     * @param _txSender The transaction sender address to add
     */
    function addTxSender(address _txSender) external onlyGov {
        _txSenders[_txSender] = true;
        emit LogTxSender(_txSender, true);
    }

    /**
     * @notice Disable a transaction sender address
     * @dev Only governance or C3Caller can call this function
     * @param _txSender The transaction sender address to disable
     */
    function disableTxSender(address _txSender) external onlyGov {
        _txSenders[_txSender] = false;
        emit LogTxSender(_txSender, false);
    }

    /**
     * @notice Execute governance operation on a single target
     * @dev Only governance or C3Caller can call this function
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata to execute
     */
    function doGov(string memory _to, string memory _toChainID, bytes memory _data) external onlyGov {
        _c3call(_to, _toChainID, _data);
    }

    /**
     * @notice Execute governance operation on multiple targets
     * @dev Only governance or C3Caller can call this function
     * @param _targets Array of target addresses on destination chains
     * @param _toChainIDs Array of destination chain identifiers
     * @param _data The calldata to execute
     * @notice Reverts if the arrays have different lengths
     */
    function doGovBroadcast(string[] memory _targets, string[] memory _toChainIDs, bytes memory _data)
        external
        onlyGov
    {
        if (_targets.length != _toChainIDs.length) {
            revert C3GovernDApp_LengthMismatch(C3ErrorParam.Target, C3ErrorParam.ChainID);
        }
        _c3broadcast(_targets, _toChainIDs, _data);
    }

    /**
     * @notice Check if an address is a valid sender for this DApp
     * @param _txSender The address to check
     * @return True if the address is a valid sender
     */
    function isValidSender(address _txSender) external view override(IC3CallerDApp, C3CallerDApp) returns (bool) {
        return _txSenders[_txSender];
    }
}
