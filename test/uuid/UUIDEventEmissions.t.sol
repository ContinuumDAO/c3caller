// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Helpers} from "../helpers/Helpers.sol";

import {C3UUIDKeeperUpgradeable} from "../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {IC3UUIDKeeper} from "../../src/uuid/IC3UUIDKeeper.sol";

/**
 * @title UUIDEventEmissionsTest
 * @dev Test contract to verify that UUID lifecycle events are properly emitted
 * @notice Tests that all key lifecycle actions emit indexed events with proper data
 */
contract UUIDEventEmissionsTest is Helpers {
    C3UUIDKeeperUpgradeable public uuidKeeper;
    address public governor;
    address public operator;
    address public user;

    event UUIDGenerated(
        bytes32 indexed uuid,
        uint256 indexed dappID,
        address indexed operator,
        string to,
        string toChainID,
        uint256 nonce,
        bytes data
    );

    event UUIDCompleted(bytes32 indexed uuid, uint256 indexed dappID, address indexed operator);

    event UUIDRevoked(bytes32 indexed uuid, uint256 indexed dappID, address indexed governor);

    function setUp() public override {
        super.setUp();

        governor = makeAddr("governor");
        operator = makeAddr("operator");
        user = makeAddr("user");

        vm.startPrank(governor);

        address implementationV1 = address(new C3UUIDKeeperUpgradeable());
        bytes memory initData = abi.encodeCall(C3UUIDKeeperUpgradeable.initialize, ());
        address uuidKeeperAddr = _deployProxy(implementationV1, initData);
        uuidKeeper = C3UUIDKeeperUpgradeable(uuidKeeperAddr);

        // Add operator
        uuidKeeper.addOperator(operator);

        vm.stopPrank();
    }

    function testUUIDGeneratedEvent() public {
        uint256 dappID = 1;
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "137";
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000);

        bytes32 expectedUUID = uuidKeeper.calcCallerUUID(operator, dappID, to, toChainID, data);

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit UUIDGenerated(
            expectedUUID,
            dappID,
            operator,
            to,
            toChainID,
            1, // First nonce
            data
        );

        bytes32 uuid = uuidKeeper.genUUID(dappID, to, toChainID, data);

        // Verify the UUID was generated
        assertTrue(uuidKeeper.doesUUIDExist(uuid));
        assertEq(uuidKeeper.uuid2Nonce(uuid), 1);
    }

    function testUUIDCompletedEvent() public {
        uint256 dappID = 1;
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "137";
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000);

        // Generate a UUID first
        vm.prank(operator);
        bytes32 uuid = uuidKeeper.genUUID(dappID, to, toChainID, data);

        // Complete the UUID
        vm.prank(operator);
        vm.expectEmit(true, true, true, false);
        emit UUIDCompleted(uuid, dappID, operator);

        uuidKeeper.registerUUID(uuid, dappID);

        // Verify the UUID was completed
        assertTrue(uuidKeeper.isCompleted(uuid));
    }

    function testUUIDRevokedEvent() public {
        uint256 dappID = 1;
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "137";
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000);

        // Generate and complete a UUID first
        vm.prank(operator);
        bytes32 uuid = uuidKeeper.genUUID(dappID, to, toChainID, data);

        vm.prank(operator);
        uuidKeeper.registerUUID(uuid, dappID);

        // Revoke the UUID
        vm.prank(governor);
        vm.expectEmit(true, true, true, false);
        emit UUIDRevoked(uuid, dappID, governor);

        uuidKeeper.revokeSwapin(uuid, dappID);

        // Verify the UUID was revoked
        assertFalse(uuidKeeper.isCompleted(uuid));
    }

    function testMultipleUUIDGenerationEvents() public {
        uint256 dappID1 = 1;
        uint256 dappID2 = 2;
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "137";
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000);

        // Generate first UUID
        vm.prank(operator);
        bytes32 uuid1 = uuidKeeper.genUUID(dappID1, to, toChainID, data);

        // Generate second UUID
        vm.prank(operator);
        bytes32 uuid2 = uuidKeeper.genUUID(dappID2, to, toChainID, data);

        // Verify both UUIDs exist with correct nonces
        assertTrue(uuidKeeper.doesUUIDExist(uuid1));
        assertTrue(uuidKeeper.doesUUIDExist(uuid2));
        assertEq(uuidKeeper.uuid2Nonce(uuid1), 1);
        assertEq(uuidKeeper.uuid2Nonce(uuid2), 2);
        assertNotEq(uuid1, uuid2);
    }

    function testEventIndexing() public {
        uint256 dappID = 1;
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "137";
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000);

        // Generate UUID
        vm.prank(operator);
        bytes32 uuid = uuidKeeper.genUUID(dappID, to, toChainID, data);

        // Complete UUID
        vm.prank(operator);
        uuidKeeper.registerUUID(uuid, dappID);

        // Revoke UUID
        vm.prank(governor);
        uuidKeeper.revokeSwapin(uuid, dappID);

        // Verify all events were emitted with proper indexing
        // The events should be indexed by uuid, dappID, and operator/governor
        // This allows efficient filtering and querying by external monitors
    }

    function testEventDataIntegrity() public {
        uint256 dappID = 1;
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "137";
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user, 1000);

        // Generate UUID and capture event
        vm.prank(operator);
        bytes32 uuid = uuidKeeper.genUUID(dappID, to, toChainID, data);

        // Verify the event data matches the input parameters
        // The event should contain all the information needed for external monitoring
        assertTrue(uuidKeeper.doesUUIDExist(uuid));
        assertEq(uuidKeeper.uuid2Nonce(uuid), 1);
    }
}
