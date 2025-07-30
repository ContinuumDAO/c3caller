// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";

import {Helpers} from "../helpers/Helpers.sol";
import {MockC3CallerDapp} from "../helpers/MockC3CallerDapp.sol";

import {IC3Caller} from "../../src/IC3Caller.sol";
import {C3Caller} from "../../src/C3Caller.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {C3CallerDapp} from "../../src/dapp/C3CallerDapp.sol";
import {IC3CallerDapp} from "../../src/dapp/IC3CallerDapp.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";

contract C3CallerDappTest is Helpers {
    C3UUIDKeeper c3UUIDKeeper;
    C3Caller c3caller;
    MockC3CallerDapp public c3CallerDapp;
    uint256 public testDappID = 123;

    function setUp() public override {
        super.setUp();

        vm.startPrank(gov);
        c3UUIDKeeper = new C3UUIDKeeper();
        c3caller = new C3Caller(address(c3UUIDKeeper));

        // Add operator permissions
        c3UUIDKeeper.addOperator(address(c3caller));
        c3caller.addOperator(gov);
        c3caller.addOperator(mpc1);

        // Deploy mock dapp
        c3CallerDapp = new MockC3CallerDapp(address(c3caller), testDappID);
        vm.stopPrank();
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public {
        assertEq(c3CallerDapp.c3CallerProxy(), address(c3caller));
        assertEq(c3CallerDapp.dappID(), testDappID);
    }

    function test_Constructor_ZeroAddressProxy() public {
        // This should work since MockC3CallerDapp doesn't validate the proxy address
        MockC3CallerDapp dapp = new MockC3CallerDapp(address(0), testDappID);
        assertEq(dapp.c3CallerProxy(), address(0));
        assertEq(dapp.dappID(), testDappID);
    }

    // ============ MODIFIER TESTS ============

    function test_OnlyCaller_Success() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        // Call from C3Caller should succeed
        vm.prank(address(c3caller));
        bool result = c3CallerDapp.c3Fallback(testDappID, data, reason);
        assertTrue(result);
    }

    function test_OnlyCaller_Revert() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        // Call from unauthorized address should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3CallerDapp.C3CallerDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.C3Caller
            )
        );
        c3CallerDapp.c3Fallback(testDappID, data, reason);
    }

    // ============ C3FALLBACK TESTS ============

    function test_C3Fallback_Success() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        bool result = c3CallerDapp.c3Fallback(testDappID, data, reason);

        assertTrue(result);
        assertEq(c3CallerDapp.lastFallbackSelector(), bytes4(keccak256("test()")));
        assertEq(c3CallerDapp.lastFallbackData(), "");
        assertEq(c3CallerDapp.lastFallbackReason(), reason);
    }

    function test_C3Fallback_WithData() public {
        bytes memory data = abi.encodeWithSignature("test(uint256)", 123);
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        bool result = c3CallerDapp.c3Fallback(testDappID, data, reason);

        assertTrue(result);
        assertEq(c3CallerDapp.lastFallbackSelector(), bytes4(keccak256("test(uint256)")));
        assertEq(c3CallerDapp.lastFallbackData(), abi.encode(123));
        assertEq(c3CallerDapp.lastFallbackReason(), reason);
    }

    function test_C3Fallback_InvalidDappID() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3CallerDapp.C3CallerDApp_InvalidDAppID.selector,
                testDappID,
                999
            )
        );
        c3CallerDapp.c3Fallback(999, data, reason);
    }

    function test_C3Fallback_EmptyData() public {
        bytes memory data = "";
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        bool result = c3CallerDapp.c3Fallback(testDappID, data, reason);

        assertTrue(result);
        assertEq(c3CallerDapp.lastFallbackSelector(), bytes4(0));
        assertEq(c3CallerDapp.lastFallbackData(), "");
        assertEq(c3CallerDapp.lastFallbackReason(), reason);
    }

    function test_C3Fallback_ShortData() public {
        bytes memory data = hex"1234"; // Only 2 bytes
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        bool result = c3CallerDapp.c3Fallback(testDappID, data, reason);

        assertTrue(result);
        assertEq(c3CallerDapp.lastFallbackSelector(), bytes4(0));
        assertEq(c3CallerDapp.lastFallbackData(), data);
        assertEq(c3CallerDapp.lastFallbackReason(), reason);
    }

    function test_C3Fallback_MockReverts() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        // Set mock to revert
        c3CallerDapp.setShouldRevert(true);

        vm.prank(address(c3caller));
        vm.expectRevert("MockC3CallerDapp: intentional revert");
        c3CallerDapp.c3Fallback(testDappID, data, reason);
    }

    // ============ ISVALID SENDER TESTS ============

    function test_IsValidSender_Default() public {
        assertTrue(c3CallerDapp.isValidSender(user1));
        assertTrue(c3CallerDapp.isValidSender(user2));
        assertTrue(c3CallerDapp.isValidSender(address(0)));
    }

    function test_IsValidSender_CustomResult() public {
        c3CallerDapp.setValidSenderResult(false);

        assertFalse(c3CallerDapp.isValidSender(user1));
        assertFalse(c3CallerDapp.isValidSender(user2));
        assertFalse(c3CallerDapp.isValidSender(address(0)));
    }

    // ============ INTERNAL FUNCTION TESTS ============

    function test_IsCaller_True() public {
        // Since C3Caller.isCaller returns true for itself
        assertTrue(c3CallerDapp.isCaller(address(c3caller)));
    }

    function test_IsCaller_False() public {
        assertFalse(c3CallerDapp.isCaller(user1));
        assertFalse(c3CallerDapp.isCaller(address(0)));
    }

    // ============ C3CALL TESTS ============

    function test_C3Call_WithoutExtra() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");

        vm.prank(address(c3caller));
        c3CallerDapp.c3call(to, toChainID, data);

        // Verify the call was made to C3Caller
        // Note: We can't easily verify the internal call, but we can test that it doesn't revert
    }

    function test_C3Call_WithExtra() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory extra = abi.encodeWithSignature("extra()");

        vm.prank(address(c3caller));
        c3CallerDapp.c3call(to, toChainID, data, extra);

        // Verify the call was made to C3Caller
        // Note: We can't easily verify the internal call, but we can test that it doesn't revert
    }

    // ============ C3BROADCAST TESTS ============

    function test_C3Broadcast() public {
        string[] memory to = new string[](2);
        to[0] = "0x1234567890123456789012345678901234567890";
        to[1] = "0x0987654321098765432109876543210987654321";

        string[] memory toChainIDs = new string[](2);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";

        bytes memory data = abi.encodeWithSignature("test()");

        vm.prank(address(c3caller));
        c3CallerDapp.c3broadcast(to, toChainIDs, data);

        // Verify the call was made to C3Caller
        // Note: We can't easily verify the internal call, but we can test that it doesn't revert
    }

    // ============ CONTEXT TESTS ============

    function test_Context() public {
        vm.prank(address(c3caller));
        (bytes32 uuid, string memory fromChainID, string memory sourceTx) = c3CallerDapp.context();

        // Since context is not set, these should be empty/default values
        assertEq(uuid, bytes32(0));
        assertEq(fromChainID, "");
        assertEq(sourceTx, "");
    }

    // ============ STRESS TESTS ============

    function test_C3Fallback_LargeData() public {
        bytes memory largeData = _generateLargeBytes(1000);
        bytes memory largeCallData = abi.encodeWithSignature("test(bytes)", largeData);
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        bool result = c3CallerDapp.c3Fallback(testDappID, largeCallData, reason);

        assertTrue(result);
        // The data passed to _c3Fallback is the ABI-encoded data without the selector
        // which includes offset (32 bytes) + length (32 bytes) + actual data
        bytes memory expectedData = abi.encode(largeData);
        assertEq(c3CallerDapp.lastFallbackData(), expectedData);
    }

    function test_C3Fallback_LargeReason() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory largeReason = _generateLargeBytes(1000);

        vm.prank(address(c3caller));
        bool result = c3CallerDapp.c3Fallback(testDappID, data, largeReason);

        assertTrue(result);
        assertEq(c3CallerDapp.lastFallbackReason(), largeReason);
    }

    function test_C3Call_LargeData() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory largeData = _generateLargeBytes(1000);

        vm.prank(address(c3caller));
        c3CallerDapp.c3call(to, toChainID, largeData);

        // Should not revert
    }

    function test_C3Broadcast_LargeArrays() public {
        string[] memory to = _generateLargeStringArray(100);
        string[] memory toChainIDs = _generateLargeStringArray(100);
        bytes memory data = abi.encodeWithSignature("test()");

        vm.prank(address(c3caller));
        c3CallerDapp.c3broadcast(to, toChainIDs, data);

        // Should not revert
    }

    // ============ EDGE CASES ============

    function test_C3Fallback_ZeroDappID() public {
        MockC3CallerDapp dapp = new MockC3CallerDapp(address(c3caller), 0);
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        bool result = dapp.c3Fallback(0, data, reason);

        assertTrue(result);
    }

    function test_C3Fallback_MaxDappID() public {
        uint256 maxDappID = type(uint256).max;
        MockC3CallerDapp dapp = new MockC3CallerDapp(address(c3caller), maxDappID);
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        vm.prank(address(c3caller));
        bool result = dapp.c3Fallback(maxDappID, data, reason);

        assertTrue(result);
    }

    function test_C3Call_EmptyTo() public {
        string memory to = "";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        vm.prank(address(c3caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.To));
        c3CallerDapp.c3call(to, toChainID, data);
    }

    function test_C3Call_EmptyToChainID() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "";
        bytes memory data = abi.encodeWithSignature("test()");
        vm.prank(address(c3caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.ChainID));
        c3CallerDapp.c3call(to, toChainID, data);
    }

    function test_C3Call_EmptyData() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = "";
        vm.prank(address(c3caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.Calldata));
        c3CallerDapp.c3call(to, toChainID, data);
    }

    function test_C3Broadcast_EmptyTo() public {
        string[] memory to = new string[](0);
        string[] memory toChainIDs = new string[](1);
        toChainIDs[0] = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");

        vm.prank(address(c3caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.To));
        c3CallerDapp.c3broadcast(to, toChainIDs, data);
    }

    function test_C3Broadcast_EmptyToChainID() public {
        string[] memory to = new string[](1);
        to[0] = "0x1234567890123456789012345678901234567890";
        string[] memory toChainIDs = new string[](0);
        bytes memory data = abi.encodeWithSignature("test()");

        vm.prank(address(c3caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.ChainID));
        c3CallerDapp.c3broadcast(to, toChainIDs, data);
    }

    function test_C3Broadcast_LengthMismatch() public {
        string[] memory to = new string[](1);
        to[0] = "0x1234567890123456789012345678901234567890";
        string[] memory toChainIDs = new string[](2);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        bytes memory data = abi.encodeWithSignature("test()");

        vm.prank(address(c3caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.ChainID));
        c3CallerDapp.c3broadcast(to, toChainIDs, data);
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function test_Gas_C3Fallback() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory reason = abi.encodeWithSignature("reason()");

        uint256 gasBefore = gasleft();
        vm.prank(address(c3caller));
        c3CallerDapp.c3Fallback(testDappID, data, reason);
        uint256 gasUsed = gasBefore - gasleft();

        // Log gas usage for optimization analysis
        console.log("Gas used for c3Fallback:", gasUsed);
    }

    function test_Gas_IsValidSender() public {
        uint256 gasBefore = gasleft();
        c3CallerDapp.isValidSender(user1);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for isValidSender:", gasUsed);
    }
}