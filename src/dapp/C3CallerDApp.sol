// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IC3Caller} from "../IC3Caller.sol";

import {C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {IC3CallerDApp} from "./IC3CallerDApp.sol";

/**
 * @title C3CallerDApp
 * @notice Abstract base contract for DApps using the C3 protocol.
 * This contract provides the foundation for DApps to interact with the C3Caller
 * system and handle cross-chain operations.
 *
 * Key features:
 * - C3Caller integration
 * - Contains a DApp ID
 * - Enables initiation of cross-chain calls
 * - Fallback mechanism for failed operations
 *
 * @dev This contract serves as the base for all user C3Caller DApps
 * @author @potti ContinuumDAO
 */
abstract contract C3CallerDApp is IC3CallerDApp {
    /// @notice The C3Caller proxy address
    address public c3caller;

    /// @notice The DApp identifier (to/from which cross-chain calls may be made)
    uint256 public dappID;

    /**
     * @notice Modifier to restrict access to C3Caller only
     * @dev Reverts if the msg.sender is not the C3Caller
     */
    modifier onlyCaller() {
        if (msg.sender != c3caller) {
            revert C3CallerDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.C3Caller);
        }
        _;
    }

    /**
     * @param _c3caller The C3Caller address
     * @param _dappID The DApp identifier
     */
    constructor(address _c3caller, uint256 _dappID) {
        c3caller = _c3caller;
        dappID = _dappID;
    }

    /**
     * @notice Handle fallbacks from C3Caller (calls that reverted on a destination network)
     * @param _dappID The DApp identifier
     * @param _data The call data
     * @param _reason The failure reason
     * @return True if the fallback was handled successfully
     * @dev Only C3Caller can call this function
     */
    function c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason)
        external
        virtual
        override
        onlyCaller
        returns (bool)
    {
        if (_dappID != dappID) {
            revert C3CallerDApp_InvalidDAppID(dappID, _dappID);
        }
        if (_data.length < 4) {
            return _c3Fallback(bytes4(0), _data, _reason);
        } else {
            return _c3Fallback(bytes4(_data[0:4]), _data[4:], _reason);
        }
    }

    /**
     * @notice Internal function to check if an address is the C3Caller
     * @param _addr The address to check
     * @return True if the address is the C3Caller
     * FIXIT: redundant
     */
    // function _isCaller(address _addr) internal virtual returns (bool) {
    //     return IC3Caller(c3CallerProxy).isCaller(_addr);
    // }

    /**
     * @notice Internal function to initiate a cross-chain call
     * @param _to The target address on the destination chain (must be same DApp ID)
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on target contract
     */
    function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal virtual {
        IC3Caller(c3caller).c3call(dappID, _to, _toChainID, _data, "");
    }

    /**
     * @notice Internal function to initiate a cross-chain call with arbitrary extra data
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on the target contract
     * @param _extra Additional arbitrary data for the cross-chain call
     */
    function _c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra)
        internal
        virtual
    {
        IC3Caller(c3caller).c3call(dappID, _to, _toChainID, _data, _extra);
    }

    /**
     * @notice Internal function to initiate cross-chain broadcasts
     * @param _to Array of target addresses on destination chains
     * @param _toChainIDs Array of destination chain IDs
     * @param _data The calldata to execute on the target contracts
     */
    function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal virtual {
        IC3Caller(c3caller).c3broadcast(dappID, _to, _toChainIDs, _data);
    }

    /**
     * @notice Internal function to handle fallback calls
     * @param _selector The function selector of the call that reverted
     * @param _data The calldata of the call that reverted
     * @param _reason The revert reason (argument of require statement OR ABI encoded custom error with its arguments)
     * @return True if the fallback was handled successfully (user-implemented)
     * @dev This function must be implemented by derived contracts to handle failed cross-chain executions
     */
    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason) internal virtual returns (bool);

    /**
     * @notice Validates if an address that called C3Caller execute and subsequently a function on this DApp
     * @param _txSender The address to check
     * @return True if the address has been previously validated
     * @dev This function must be implemented by derived contracts
     */
    function isValidSender(address _txSender) external view virtual returns (bool);

    /**
     * @notice Internal function to get some useful information related to the transaction on the source network
     * @return uuid The UUID of the current cross-chain operation
     * @return fromChainID The source chain identifier
     * @return sourceTx The source transaction hash
     * @dev Accessible in functions that implement `onlyCaller` modifier
     */
    function _context()
        internal
        view
        virtual
        returns (bytes32 uuid, string memory fromChainID, string memory sourceTx)
    {
        return IC3Caller(c3caller).context();
    }
}
