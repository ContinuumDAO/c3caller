// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IC3Caller } from "../../IC3Caller.sol";

import { IC3CallerDapp } from "../../dapp/IC3CallerDapp.sol";
import { C3ErrorParam } from "../../utils/C3CallerUtils.sol";

/**
 * @title C3CallerDappUpgradeable
 * @dev Abstract base contract for upgradeable dApps in the C3 protocol.
 * This contract provides the foundation for dApps to interact with the C3Caller
 * system and handle cross-chain operations in an upgradeable context.
 *
 * Key features:
 * - Upgradeable storage using ERC-7201 pattern
 * - C3Caller proxy integration
 * - dApp identifier management
 * - Cross-chain call initiation
 * - Fallback mechanism for failed operations
 * - Context retrieval for cross-chain operations
 *
 * @notice This contract serves as the base for all upgradeable C3 dApps
 * @author @potti ContinuumDAO
 */
abstract contract C3CallerDappUpgradeable is IC3CallerDapp, Initializable {
    /**
     * @dev Storage struct for C3CallerDapp using ERC-7201 storage pattern
     * @custom:storage-location erc7201:c3caller.storage.C3CallerDapp
     */
    struct C3CallerDappStorage {
        /// @notice The C3Caller proxy address
        address c3CallerProxy;
        /// @notice The dApp identifier
        uint256 dappID;
    }

    // keccak256(abi.encode(uint256(keccak256("c3caller.storage.C3CallerDapp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant C3CallerDappStorageLocation =
        0xa39433114fd213b64ea52624936c26398cba31e0774cfae377a12cb547f1bb00;

    /**
     * @dev Get the storage struct for C3CallerDapp
     * @return $ The storage struct
     */
    function _getC3CallerDappStorage() private pure returns (C3CallerDappStorage storage $) {
        assembly {
            $.slot := C3CallerDappStorageLocation
        }
    }

    /**
     * @dev Internal initializer for upgradeable dApps
     * @param _c3CallerProxy The C3Caller proxy address
     * @param _dappID The dApp identifier
     */
    function __C3CallerDapp_init(address _c3CallerProxy, uint256 _dappID) internal onlyInitializing {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        $.c3CallerProxy = _c3CallerProxy;
        $.dappID = _dappID;
    }

    /**
     * @dev Modifier to restrict access to C3Caller only
     * @notice Reverts if the caller is not the C3Caller
     */
    modifier onlyCaller() {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        if (!IC3Caller($.c3CallerProxy).isCaller(msg.sender)) {
            revert C3CallerDApp_OnlyAuthorized(C3ErrorParam.Sender, C3ErrorParam.C3Caller);
        }
        _;
    }

    /**
     * @notice Handle fallback calls from C3Caller
     * @dev Only C3Caller can call this function
     * @param _dappID The dApp identifier
     * @param _data The call data
     * @param _reason The failure reason
     * @return True if the fallback was handled successfully
     */
    function c3Fallback(uint256 _dappID, bytes calldata _data, bytes calldata _reason)
        external
        virtual
        override
        onlyCaller
        returns (bool)
    {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        if (_dappID != $.dappID) {
            revert C3CallerDApp_InvalidDAppID($.dappID, _dappID);
        }
        return _c3Fallback(bytes4(_data[0:4]), _data[4:], _reason);
    }

    /**
     * @notice Check if an address is a valid sender for this dApp
     * @param _txSender The address to check
     * @return True if the address is a valid sender
     * @dev This function must be implemented by derived contracts
     */
    function isValidSender(address _txSender) external view virtual returns (bool);

    /**
     * @notice Get the C3Caller proxy address
     * @return The C3Caller proxy address
     */
    function c3CallerProxy() public view virtual returns (address) {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return $.c3CallerProxy;
    }

    /**
     * @notice Get the dApp identifier
     * @return The dApp identifier
     */
    function dappID() public view virtual returns (uint256) {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return $.dappID;
    }

    /**
     * @dev Internal function to check if an address is the C3Caller
     * @param _addr The address to check
     * @return True if the address is the C3Caller
     */
    function _isCaller(address _addr) internal virtual returns (bool) {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return IC3Caller($.c3CallerProxy).isCaller(_addr);
    }

    /**
     * @dev Internal function to handle fallback calls
     * @param _selector The function selector
     * @param _data The call data
     * @param _reason The failure reason
     * @return True if the fallback was handled successfully
     * @dev This function must be implemented by derived contracts
     */
    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        virtual
        returns (bool);

    /**
     * @dev Internal function to initiate a cross-chain call
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata to execute
     */
    function _c3call(string memory _to, string memory _toChainID, bytes memory _data) internal virtual {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        IC3Caller($.c3CallerProxy).c3call($.dappID, _to, _toChainID, _data, "");
    }

    /**
     * @dev Internal function to initiate a cross-chain call with extra data
     * @param _to The target address on the destination chain
     * @param _toChainID The destination chain identifier
     * @param _data The calldata to execute
     * @param _extra Additional data for the cross-chain call
     */
    function _c3call(string memory _to, string memory _toChainID, bytes memory _data, bytes memory _extra)
        internal
        virtual
    {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        IC3Caller($.c3CallerProxy).c3call($.dappID, _to, _toChainID, _data, _extra);
    }

    /**
     * @dev Internal function to initiate cross-chain broadcasts
     * @param _to Array of target addresses on destination chains
     * @param _toChainIDs Array of destination chain identifiers
     * @param _data The calldata to execute on destination chains
     */
    function _c3broadcast(string[] memory _to, string[] memory _toChainIDs, bytes memory _data) internal virtual {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        IC3Caller($.c3CallerProxy).c3broadcast($.dappID, _to, _toChainIDs, _data);
    }

    /**
     * @dev Internal function to get the current cross-chain context
     * @return uuid The UUID of the current cross-chain operation
     * @return fromChainID The source chain identifier
     * @return sourceTx The source transaction hash
     */
    function _context()
        internal
        view
        virtual
        returns (bytes32 uuid, string memory fromChainID, string memory sourceTx)
    {
        C3CallerDappStorage storage $ = _getC3CallerDappStorage();
        return IC3Caller($.c3CallerProxy).context();
    }
}
