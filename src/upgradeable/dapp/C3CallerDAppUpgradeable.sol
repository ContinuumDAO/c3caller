// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IC3CallerDApp} from "../../dapp/IC3CallerDApp.sol";
import {IC3Caller} from "../../IC3Caller.sol";
import {C3ErrorParam} from "../../utils/C3CallerUtils.sol";

/**
 * @title C3CallerDAppUpgradeable
 * @notice Abstract base contract for upgradeable DApps using the C3 protocol.
 * This contract provides the foundation for DApps to interact with the C3Caller
 * system and handle cross-chain operations in an upgradeable context.
 *
 * Key features:
 * - C3Caller integration
 * - Contains a DApp ID
 * - Enables initiation of cross-chain calls
 * - Fallback mechanism for failed operations
 * - Upgradeable storage using ERC-7201 pattern
 *
 * @dev This contract serves as the base for all upgradeable C3Caller DApps
 * @author @potti ContinuumDAO
 */
abstract contract C3CallerDAppUpgradeable is IC3CallerDApp, Initializable {
    /**
     * @dev Storage struct for C3CallerDApp using ERC-7201 storage pattern
     * @custom:storage-location erc7201:c3caller.storage.C3CallerDApp
     */
    struct C3CallerDAppStorage {
        /// @notice The DApp identifier
        uint256 dappID;
        /// @notice The C3Caller address
        address c3caller;
    }

    // keccak256(abi.encode(uint256(keccak256(bytes("c3caller.storage.C3CallerDApp"))) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3CallerDAppStorageLocation =
        0xb8c52ef1c1980f4ee6284e96cd37d6632554e7d3ff4cf7b91d46dcb2bc87b300;

    /**
     * @notice Get the DApp identifier
     * @return The DApp identifier
     */
    function dappID() public view virtual returns (uint256) {
        C3CallerDAppStorage storage $ = _getC3CallerDAppStorage();
        return $.dappID;
    }

    /**
     * @notice Get the C3Caller proxy address
     * @return The C3Caller proxy address
     */
    function c3caller() public view virtual returns (address) {
        C3CallerDAppStorage storage $ = _getC3CallerDAppStorage();
        return $.c3caller;
    }

    /**
     * @notice Modifier to restrict access to C3Caller only
     * @dev Reverts if the msg.sender is not the C3Caller
     */
    modifier onlyC3Caller() {
        if (msg.sender != c3caller()) {
            revert C3CallerDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.C3Caller);
        }
        _;
    }

    /**
     * @notice Internal initializer for the upgradeable C3CallerDApp contract
     * @param _c3caller The C3Caller proxy address
     * @param _dappID The DApp identifier
     */
    function __C3CallerDApp_init(address _c3caller, uint256 _dappID) internal onlyInitializing {
        C3CallerDAppStorage storage $ = _getC3CallerDAppStorage();
        $.c3caller = _c3caller;
        $.dappID = _dappID;
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
        onlyC3Caller
        returns (bool)
    {
        uint256 dappID_ = dappID();
        if (_dappID != dappID_) {
            revert C3CallerDApp_InvalidDAppID(dappID_, _dappID);
        }
        if (_data.length < 4) {
            return _c3Fallback(bytes4(0), _data, _reason);
        } else {
            return _c3Fallback(bytes4(_data[0:4]), _data[4:], _reason);
        }
    }

    /**
     * @notice Internal function to initiate a cross-chain call
     * @param _to The target address on the destination chain (must be same DApp ID)
     * @param _toChainID The destination chain ID
     * @param _data The calldata to execute on target contract
     */
    function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal virtual returns (bytes32) {
        return IC3Caller(c3caller()).c3call(dappID(), _to, _toChainID, _data, "");
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
        returns (bytes32)
    {
        return IC3Caller(c3caller()).c3call(dappID(), _to, _toChainID, _data, _extra);
    }

    /**
     * @notice Internal function to initiate cross-chain broadcasts
     * @param _to Array of target addresses on destination chains
     * @param _toChainIDs Array of destination chain IDs
     * @param _data The calldata to execute on the target contracts
     */
    function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal virtual returns (bytes32[] memory){
        return IC3Caller(c3caller()).c3broadcast(dappID(), _to, _toChainIDs, _data);
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
        return IC3Caller(c3caller()).context();
    }

    /**
     * @notice Get the storage struct for C3CallerDApp
     * @return $ The storage struct
     */
    function _getC3CallerDAppStorage() private pure returns (C3CallerDAppStorage storage $) {
        assembly {
            $.slot := C3CallerDAppStorageLocation
        }
    }
}
