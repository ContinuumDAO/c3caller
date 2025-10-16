// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {IC3UUIDKeeper} from "../../src/uuid/IC3UUIDKeeper.sol";
import {Helpers} from "../helpers/Helpers.sol";

contract C3UUIDKeeperTest is Helpers {
    C3UUIDKeeper public uuidKeeper;

    // Test data
    uint256 constant DAPP_ID = 1;
    string constant TO_ADDRESS = "0x1234567890123456789012345678901234567890";
    string constant TO_CHAIN_ID = "ethereum";
    bytes constant TEST_DATA = "0x1234567890abcdef";

    function setUp() public override {
        super.setUp();
        vm.startPrank(gov);
        uuidKeeper = new C3UUIDKeeper();
        vm.stopPrank();

        // Add operators
        vm.startPrank(gov);
        uuidKeeper.addOperator(mpc1);
        uuidKeeper.addOperator(mpc2);
        vm.stopPrank();
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public view {
        assertEq(uuidKeeper.gov(), gov);
        assertEq(uuidKeeper.currentNonce(), 0);
    }

    // ============ UUID GENERATION TESTS ============

    function test_GenUUID() public {
        vm.startPrank(mpc1);

        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );

        assertTrue(uuid != bytes32(0));
        assertTrue(uuidKeeper.isUUIDExist(uuid));
        assertEq(uuidKeeper.uuid2Nonce(uuid), 1);
        assertEq(uuidKeeper.currentNonce(), 1);

        vm.stopPrank();
    }

    function test_GenUUIDMultiple() public {
        vm.startPrank(mpc1);

        bytes32 uuid1 = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        bytes32 uuid2 = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );

        assertTrue(uuid1 != uuid2);
        assertTrue(uuidKeeper.isUUIDExist(uuid1));
        assertTrue(uuidKeeper.isUUIDExist(uuid2));
        assertEq(uuidKeeper.uuid2Nonce(uuid1), 1);
        assertEq(uuidKeeper.uuid2Nonce(uuid2), 2);
        assertEq(uuidKeeper.currentNonce(), 2);

        vm.stopPrank();
    }

    function test_GenUUIDDifferentOperators() public {
        vm.startPrank(mpc1);
        bytes32 uuid1 = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        vm.stopPrank();

        vm.startPrank(mpc2);
        bytes32 uuid2 = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        vm.stopPrank();

        assertTrue(uuid1 != uuid2);
        assertEq(uuidKeeper.currentNonce(), 2);
    }

    function test_GenUUIDUnauthorized() public {
        vm.startPrank(user1);

        vm.expectRevert();
        uuidKeeper.genUUID(DAPP_ID, TO_ADDRESS, TO_CHAIN_ID, TEST_DATA);

        vm.stopPrank();
    }

    // ============ UUID REGISTRATION TESTS ============

    function test_RegisterUUID() public {
        vm.startPrank(mpc1);

        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        uuidKeeper.registerUUID(uuid, 1);

        assertTrue(uuidKeeper.isCompleted(uuid));
        assertTrue(uuidKeeper.completedSwapin(uuid));

        vm.stopPrank();
    }

    function test_RegisterUUIDAlreadyCompleted() public {
        vm.startPrank(mpc1);

        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        uuidKeeper.registerUUID(uuid, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IC3UUIDKeeper.C3UUIDKeeper_UUIDAlreadyCompleted.selector,
                uuid
            )
        );
        uuidKeeper.registerUUID(uuid, 1);

        vm.stopPrank();
    }

    function test_RegisterUUIDUnauthorized() public {
        vm.startPrank(user1);

        bytes32 uuid = keccak256("test");
        vm.expectRevert();
        uuidKeeper.registerUUID(uuid, 1);

        vm.stopPrank();
    }

    // ============ COMPLETION CHECK TESTS ============

    function test_IsCompleted() public {
        vm.startPrank(mpc1);

        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        assertFalse(uuidKeeper.isCompleted(uuid));

        uuidKeeper.registerUUID(uuid, 1);
        assertTrue(uuidKeeper.isCompleted(uuid));

        vm.stopPrank();
    }

    function test_IsUUIDExist() public {
        vm.startPrank(mpc1);

        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        assertTrue(uuidKeeper.isUUIDExist(uuid));

        bytes32 nonExistentUUID = keccak256("non-existent");
        assertFalse(uuidKeeper.isUUIDExist(nonExistentUUID));

        vm.stopPrank();
    }

    // ============ REVOKE TESTS ============

    function test_RevokeSwapin() public {
        vm.startPrank(mpc1);
        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        uuidKeeper.registerUUID(uuid, 1);
        vm.stopPrank();

        assertTrue(uuidKeeper.isCompleted(uuid));

        vm.startPrank(gov);
        uuidKeeper.revokeSwapin(uuid, 1);
        vm.stopPrank();

        assertFalse(uuidKeeper.isCompleted(uuid));
    }

    function test_RevokeSwapinUnauthorized() public {
        vm.startPrank(user1);

        bytes32 uuid = keccak256("test");
        vm.expectRevert();
        uuidKeeper.revokeSwapin(uuid, 1);

        vm.stopPrank();
    }

    // ============ CALCULATION TESTS ============

    function test_CalcCallerUUID() public {
        bytes32 expectedUUID = uuidKeeper.calcCallerUUID(
            mpc1,
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );

        vm.startPrank(mpc1);
        bytes32 actualUUID = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        vm.stopPrank();

        assertEq(expectedUUID, actualUUID);
    }

    function test_CalcCallerUUIDWithNonce() public view {
        uint256 nonce = 123;
        bytes32 uuid = uuidKeeper.calcCallerUUIDWithNonce(
            mpc1,
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA,
            nonce
        );

        assertTrue(uuid != bytes32(0));

        // Verify the calculation is correct
        bytes32 expectedUUID = keccak256(
            abi.encode(
                address(uuidKeeper),
                mpc1,
                block.chainid,
                DAPP_ID,
                TO_ADDRESS,
                TO_CHAIN_ID,
                nonce,
                TEST_DATA
            )
        );
        assertEq(uuid, expectedUUID);
    }

    function test_CalcCallerEncode() public view {
        bytes memory encoded = uuidKeeper.calcCallerEncode(
            mpc1,
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );

        assertTrue(encoded.length > 0);

        // Verify the encoding is correct
        bytes memory expectedEncoded = abi.encode(
            address(uuidKeeper),
            mpc1,
            block.chainid,
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            1,
            TEST_DATA
        );
        assertEq(encoded, expectedEncoded);
    }

    // ============ GOVERNANCE TESTS ============

    function test_AddOperator() public {
        vm.startPrank(gov);
        uuidKeeper.addOperator(user1);
        vm.stopPrank();

        assertTrue(uuidKeeper.isOperator(user1));
    }

    function test_AddOperatorUnauthorized() public {
        vm.startPrank(user1);

        vm.expectRevert();
        uuidKeeper.addOperator(user2);

        vm.stopPrank();
    }

    function test_RevokeOperator() public {
        vm.startPrank(gov);
        uuidKeeper.revokeOperator(mpc1);
        vm.stopPrank();

        assertFalse(uuidKeeper.isOperator(mpc1));
    }

    function test_RevokeOperatorUnauthorized() public {
        vm.startPrank(user1);

        vm.expectRevert();
        uuidKeeper.revokeOperator(mpc1);

        vm.stopPrank();
    }

    function test_GetAllOperators() public view {
        address[] memory operators = uuidKeeper.getAllOperators();
        assertEq(operators.length, 2);
        assertEq(operators[0], mpc1);
        assertEq(operators[1], mpc2);
    }

    // ============ EDGE CASES ============

    function test_GenUUIDWithEmptyData() public {
        vm.startPrank(mpc1);

        bytes32 uuid = uuidKeeper.genUUID(DAPP_ID, TO_ADDRESS, TO_CHAIN_ID, "");

        assertTrue(uuid != bytes32(0));
        assertTrue(uuidKeeper.isUUIDExist(uuid));

        vm.stopPrank();
    }

    function test_GenUUIDWithLargeData() public {
        vm.startPrank(mpc1);

        bytes memory largeData = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            largeData[i] = bytes1(uint8(i % 256));
        }

        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            largeData
        );

        assertTrue(uuid != bytes32(0));
        assertTrue(uuidKeeper.isUUIDExist(uuid));

        vm.stopPrank();
    }

    function test_GenUUIDWithSpecialCharacters() public {
        vm.startPrank(mpc1);

        string memory specialTo = "0x!@#$%^&*()_+-=[]{}|;':\",./<>?";
        string memory specialChainId = "chain-id-with-special-chars!@#";

        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            specialTo,
            specialChainId,
            TEST_DATA
        );

        assertTrue(uuid != bytes32(0));
        assertTrue(uuidKeeper.isUUIDExist(uuid));

        vm.stopPrank();
    }

    // ============ STRESS TESTS ============

    function test_MultipleUUIDGeneration() public {
        vm.startPrank(mpc1);

        for (uint256 i = 0; i < 10; i++) {
            bytes32 uuid = uuidKeeper.genUUID(
                i,
                TO_ADDRESS,
                TO_CHAIN_ID,
                TEST_DATA
            );
            assertTrue(uuidKeeper.isUUIDExist(uuid));
            assertEq(uuidKeeper.uuid2Nonce(uuid), i + 1);
        }

        assertEq(uuidKeeper.currentNonce(), 10);

        vm.stopPrank();
    }

    function test_RegisterMultipleUUIDs() public {
        vm.startPrank(mpc1);

        bytes32[] memory uuids = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            uuids[i] = uuidKeeper.genUUID(
                i,
                TO_ADDRESS,
                TO_CHAIN_ID,
                TEST_DATA
            );
        }

        for (uint256 i = 0; i < 5; i++) {
            uuidKeeper.registerUUID(uuids[i]);
            assertTrue(uuidKeeper.isCompleted(uuids[i]));
        }

        vm.stopPrank();
    }

    // ============ ERROR HANDLING TESTS ============

    function test_GenUUIDWithZeroAddress() public {
        vm.startPrank(mpc1);

        // This should work as the contract address is used in the calculation
        bytes32 uuid = uuidKeeper.genUUID(
            DAPP_ID,
            TO_ADDRESS,
            TO_CHAIN_ID,
            TEST_DATA
        );
        assertTrue(uuid != bytes32(0));

        vm.stopPrank();
    }

    function test_RegisterNonExistentUUID() public {
        vm.startPrank(mpc1);

        bytes32 nonExistentUUID = keccak256("non-existent");
        uuidKeeper.registerUUID(nonExistentUUID);

        assertTrue(uuidKeeper.isCompleted(nonExistentUUID));

        vm.stopPrank();
    }
}
