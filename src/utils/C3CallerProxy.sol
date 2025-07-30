// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/**
 * @title C3CallerProxy
 * @dev Proxy contract for C3Caller implementation using ERC1967 standard.
 * This contract acts as a proxy to the actual C3Caller implementation,
 * allowing for upgradeable functionality while maintaining the same interface.
 * 
 * The proxy delegates all calls to the implementation contract and provides
 * a way to retrieve the current implementation address.
 * 
 * @notice This contract enables upgradeable C3Caller functionality
 * @author @potti ContinuumDAO
 */
contract C3CallerProxy is ERC1967Proxy {
    /**
     * @dev Constructor for C3CallerProxy
     * @param _implementation Address of the implementation contract
     * @param _data Initialization data for the implementation contract
     */
    constructor(address _implementation, bytes memory _data) ERC1967Proxy(_implementation, _data) { }

    /**
     * @notice Get the current implementation address
     * @return The address of the current implementation contract
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @dev Fallback function to receive ETH
     * Allows the contract to receive ETH transfers
     */
    receive() external payable { }
}
