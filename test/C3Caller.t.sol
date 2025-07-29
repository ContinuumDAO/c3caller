// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { IC3Caller } from "../src/IC3Caller.sol";

import { IC3CallerDapp } from "../src/dapp/IC3CallerDapp.sol";
import { IC3GovClient } from "../src/gov/IC3GovClient.sol";
import { C3ErrorParam } from "../src/utils/C3CallerUtils.sol";
import { Helpers } from "./helpers/Helpers.sol";
import { MockC3CallerDapp } from "./helpers/MockC3CallerDapp.sol";

contract C3CallerTest is Helpers {
    MockC3CallerDapp public mockDapp;
    uint256 public testDappID = 123;

    function setUp() public virtual override {
        super.setUp();

        // Add operator permissions
        vm.startPrank(gov);
        c3UUIDKeeper.addOperator(address(c3caller)); // Add C3Caller as operator to C3UUIDKeeper
        c3caller.addOperator(gov); // Add gov as an operator to C3Caller
        vm.stopPrank();

        // Deploy mock dapp
        mockDapp = new MockC3CallerDapp(address(c3caller), testDappID);
    }

    function test_Constructor() public {
        assertEq(c3caller.gov(), gov);
        // Gov is always allowed, but not necessarily stored as an operator
        // Let's check if gov can call operator functions
        vm.prank(gov);
        assertTrue(c3caller.isExecutor(gov));
    }

    function test_C3Call() public {
        bytes memory data = abi.encodeWithSignature("test()");
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "_toChainID";
        uint256 dappID = 1;

        // Calculate expected UUID
        bytes32 uuid = c3UUIDKeeper.calcCallerUUID(address(c3caller), dappID, to, toChainID, data);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID, // indexed dappID
            uuid, // indexed uuid
            user1, // caller
            toChainID, // toChainID
            to, // to
            data, // data
            "" // empty extra data
        );
        c3caller.c3call(dappID, to, toChainID, data);
    }

    function test_C3CallWithExtraData() public {
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory extraData = abi.encodeWithSignature("extra()");
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "_toChainID";
        uint256 dappID = 1;

        // Calculate expected UUID
        bytes32 uuid = c3UUIDKeeper.calcCallerUUID(address(c3caller), dappID, to, toChainID, data);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID, // indexed dappID
            uuid, // indexed uuid
            user1, // caller
            toChainID, // toChainID
            to, // to
            data, // data
            extraData // extra data
        );
        c3caller.c3call(dappID, to, toChainID, data, extraData);
    }

    function test_C3Broadcast() public {
        string[] memory to = new string[](2);
        to[0] = "0x1234567890123456789012345678901234567890";
        to[1] = "0x0987654321098765432109876543210987654321";

        string[] memory toChainIDs = new string[](2);
        toChainIDs[0] = "chain1";
        toChainIDs[1] = "chain2";

        bytes memory data = abi.encodeWithSignature("test()");
        uint256 dappID = 1;

        // Calculate expected UUIDs for each destination
        bytes32 uuid1 = c3UUIDKeeper.calcCallerUUIDWithNonce(address(c3caller), dappID, to[0], toChainIDs[0], data, 1);
        bytes32 uuid2 = c3UUIDKeeper.calcCallerUUIDWithNonce(address(c3caller), dappID, to[1], toChainIDs[1], data, 2);

        // Expect events for both destinations
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID, // indexed dappID
            uuid1, // indexed uuid
            user1, // caller
            toChainIDs[0], // toChainID
            to[0], // to
            data, // data
            "" // empty extra data
        );

        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID, // indexed dappID
            uuid2, // indexed uuid
            user1, // caller
            toChainIDs[1], // toChainID
            to[1], // to
            data, // data
            "" // empty extra data
        );

        c3caller.c3broadcast(dappID, to, toChainIDs, data);
        vm.stopPrank();
    }

    // ============ EXECUTE TESTS ============

    function test_Execute_SuccessfulCall() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecCall(
            testDappID,
            address(mockDapp),
            uuid,
            "ethereum",
            "0x1234567890abcdef",
            data,
            true, // success
            abi.encode(uint256(1)) // result
        );

        c3caller.execute(testDappID, message);

        // Verify UUID was registered
        assertTrue(c3UUIDKeeper.isCompleted(uuid));
    }

    function test_Execute_FailedCall() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("failedCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecCall(
            testDappID,
            address(mockDapp),
            uuid,
            "ethereum",
            "0x1234567890abcdef",
            data,
            true, // success
            abi.encode(uint256(0)) // result
        );

        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogFallbackCall(
            testDappID,
            uuid,
            "", // fallbackTo is empty
            abi.encodeWithSelector(IC3CallerDapp.c3Fallback.selector, testDappID, data, abi.encode(uint256(0))),
            abi.encode(uint256(0))
        );

        c3caller.execute(testDappID, message);

        // Verify UUID was NOT registered (because call failed)
        assertFalse(c3UUIDKeeper.isCompleted(uuid));
    }

    function test_Execute_RevertingCall() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("revertingCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecCall(
            testDappID,
            address(mockDapp),
            uuid,
            "ethereum",
            "0x1234567890abcdef",
            data,
            false, // success
            abi.encodeWithSignature("Error(string)", "MockC3CallerDapp: call reverted") // ABI-encoded error
        );

        c3caller.execute(testDappID, message);

        // Verify UUID was NOT registered (because call reverted)
        assertFalse(c3UUIDKeeper.isCompleted(uuid));
    }

    function test_Execute_InvalidDataCall() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("invalidDataCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecCall(
            testDappID,
            address(mockDapp),
            uuid,
            "ethereum",
            "0x1234567890abcdef",
            data,
            true, // success
            abi.encode("invalid") // result
        );

        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogFallbackCall(
            testDappID,
            uuid,
            "", // fallbackTo is empty
            abi.encodeWithSelector(IC3CallerDapp.c3Fallback.selector, testDappID, data, abi.encode("invalid")),
            abi.encode("invalid")
        );

        c3caller.execute(testDappID, message);

        // Verify UUID was NOT registered (because data is invalid)
        assertFalse(c3UUIDKeeper.isCompleted(uuid));
    }

    function test_Execute_WithFallbackTo() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("failedCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "0xfallbackaddress",
            data: data
        });

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecCall(
            testDappID,
            address(mockDapp),
            uuid,
            "ethereum",
            "0x1234567890abcdef",
            data,
            true, // success
            abi.encode(uint256(0)) // result
        );

        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogFallbackCall(
            testDappID,
            uuid,
            "0xfallbackaddress", // fallbackTo
            abi.encodeWithSelector(IC3CallerDapp.c3Fallback.selector, testDappID, data, abi.encode(uint256(0))),
            abi.encode(uint256(0))
        );

        c3caller.execute(testDappID, message);
    }

    function test_Execute_EmptyData() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = "";

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.Calldata));
        c3caller.execute(testDappID, message);
    }

    function test_Execute_InvalidSender() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        // Set mock dapp to reject sender
        mockDapp.setValidSenderResult(false);

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3Caller.C3Caller_OnlyAuthorized.selector, C3ErrorParam.To, C3ErrorParam.Valid)
        );
        c3caller.execute(testDappID, message);
    }

    function test_Execute_DappIDMismatch() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidDAppID.selector, testDappID, 999));
        c3caller.execute(999, message); // Wrong dappID
    }

    function test_Execute_UUIDAlreadyCompleted() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        // Mark UUID as completed
        vm.prank(gov);
        c3UUIDKeeper.registerUUID(uuid);

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_UUIDAlreadyCompleted.selector, uuid));
        c3caller.execute(testDappID, message);
    }

    function test_Execute_NonOperator() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(user1); // Non-operator
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrOperator
            )
        );
        c3caller.execute(testDappID, message);
    }

    // ============ C3FALLBACK TESTS ============

    function test_C3Fallback_Successful() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecFallback(
            testDappID,
            address(mockDapp),
            uuid,
            "ethereum",
            "0x1234567890abcdef",
            data,
            abi.encode(uint256(1)) // result
        );

        c3caller.c3Fallback(testDappID, message);

        // Verify UUID was registered
        assertTrue(c3UUIDKeeper.isCompleted(uuid));

        // Note: c3Fallback calls the target contract directly, not through the mock dapp's c3Fallback function
        // so we don't check the mock dapp's fallback state
    }

    function test_C3Fallback_EmptyData() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = "";

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.Calldata));
        c3caller.c3Fallback(testDappID, message);
    }

    function test_C3Fallback_InvalidSender() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        // Set mock dapp to reject sender
        mockDapp.setValidSenderResult(false);

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3Caller.C3Caller_OnlyAuthorized.selector, C3ErrorParam.To, C3ErrorParam.Valid)
        );
        c3caller.c3Fallback(testDappID, message);
    }

    function test_C3Fallback_DappIDMismatch() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidDAppID.selector, testDappID, 999));
        c3caller.c3Fallback(999, message); // Wrong dappID
    }

    function test_C3Fallback_UUIDAlreadyCompleted() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        // Mark UUID as completed
        vm.prank(gov);
        c3UUIDKeeper.registerUUID(uuid);

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_UUIDAlreadyCompleted.selector, uuid));
        c3caller.c3Fallback(testDappID, message);
    }

    function test_C3Fallback_NonOperator() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(user1); // Non-operator
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrOperator
            )
        );
        c3caller.c3Fallback(testDappID, message);
    }

    function test_C3Fallback_MockDappReverts() public {
        bytes32 uuid = keccak256("test-uuid");
        bytes memory data = abi.encodeWithSignature("successfulCall()");

        // Set mock dapp to revert in fallback
        mockDapp.setShouldRevert(true);

        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage({
            uuid: uuid,
            to: address(mockDapp),
            fromChainID: "ethereum",
            sourceTx: "0x1234567890abcdef",
            fallbackTo: "",
            data: data
        });

        vm.prank(gov);
        // The c3Fallback function will call the mock dapp's c3Fallback function directly
        // which will revert with our custom message
        vm.expectRevert("MockC3CallerDapp: intentional revert");
        c3caller.c3Fallback(testDappID, message);
    }

    // ============ STRESS TESTS ============

    function test_C3Call_StressTest_LargeData() public {
        // Create a large amount of data with many parameters
        uint256[] memory largeArray = new uint256[](1000);
        for (uint256 i = 0; i < 1000; i++) {
            largeArray[i] = i;
        }

        // Create complex nested data structure
        bytes memory complexData = abi.encodeWithSignature(
            "complexFunction(uint256[],string[],address[],bool[])",
            largeArray,
            _generateLargeStringArray(500),
            _generateLargeAddressArray(300),
            _generateLargeBoolArray(200)
        );

        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "_toChainID";
        uint256 dappID = 1;

        // Calculate expected UUID
        bytes32 uuid = c3UUIDKeeper.calcCallerUUID(address(c3caller), dappID, to, toChainID, complexData);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID,
            uuid,
            user1,
            toChainID,
            to,
            complexData,
            "" // empty extra data
        );
        c3caller.c3call(dappID, to, toChainID, complexData);
    }

    function test_C3Call_StressTest_ManyParameters() public {
        // Test with many different parameters in a single call
        bytes memory data = abi.encodeWithSignature(
            "multiParamFunction(uint256,string,address,bool,bytes32,uint8,int256,uint128,bytes,uint256[])",
            123_456_789,
            "very_long_string_parameter_with_many_characters_to_test_string_handling_capabilities",
            address(0x1234567890123456789012345678901234567890),
            true,
            keccak256("test_hash"),
            255,
            -123_456_789,
            987_654_321,
            _generateLargeBytes(1000),
            _generateLargeUintArray(100)
        );

        string memory to = "0x0987654321098765432109876543210987654321";
        string memory toChainID = "ethereum_mainnet_chain_id_very_long";
        uint256 dappID = 999_999;

        // Calculate expected UUID
        bytes32 uuid = c3UUIDKeeper.calcCallerUUID(address(c3caller), dappID, to, toChainID, data);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID,
            uuid,
            user2,
            toChainID,
            to,
            data,
            "" // empty extra data
        );
        c3caller.c3call(dappID, to, toChainID, data);
    }

    function test_C3Call_StressTest_MaximumDataSize() public {
        // Test with data size approaching block gas limit
        bytes memory maxData = _generateLargeBytes(50_000); // Large but reasonable size

        string memory to = "0xabcdef1234567890abcdef1234567890abcdef12";
        string memory toChainID = "polygon";
        uint256 dappID = 1;

        // Calculate expected UUID
        bytes32 uuid = c3UUIDKeeper.calcCallerUUID(address(c3caller), dappID, to, toChainID, maxData);

        vm.prank(operator1);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID,
            uuid,
            operator1,
            toChainID,
            to,
            maxData,
            "" // empty extra data
        );
        c3caller.c3call(dappID, to, toChainID, maxData);
    }

    function test_C3Call_StressTest_ComplexExtraData() public {
        // Test with complex extra data
        bytes memory data = abi.encodeWithSignature("simpleFunction()");
        bytes memory extraData = abi.encodeWithSignature(
            "complexExtraData(uint256[],string[],address[],bool[],bytes[])",
            _generateLargeUintArray(200),
            _generateLargeStringArray(100),
            _generateLargeAddressArray(150),
            _generateLargeBoolArray(75),
            _generateLargeBytesArray(50)
        );

        string memory to = "0x1111111111111111111111111111111111111111";
        string memory toChainID = "bsc";
        uint256 dappID = 1;

        // Calculate expected UUID
        bytes32 uuid = c3UUIDKeeper.calcCallerUUID(address(c3caller), dappID, to, toChainID, data);

        vm.prank(operator2);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(dappID, uuid, operator2, toChainID, to, data, extraData);
        c3caller.c3call(dappID, to, toChainID, data, extraData);
    }

    // ============ HELPER FUNCTIONS FOR STRESS TESTS ============

    function _generateLargeStringArray(uint256 size) internal pure returns (string[] memory) {
        string[] memory array = new string[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = string(abi.encodePacked("string_", i, "_with_many_characters_to_test_string_handling"));
        }
        return array;
    }

    function _generateLargeAddressArray(uint256 size) internal pure returns (address[] memory) {
        address[] memory array = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = address(uint160(i + 1));
        }
        return array;
    }

    function _generateLargeBoolArray(uint256 size) internal pure returns (bool[] memory) {
        bool[] memory array = new bool[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = i % 2 == 0;
        }
        return array;
    }

    function _generateLargeUintArray(uint256 size) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = i * 123_456_789;
        }
        return array;
    }

    function _generateLargeBytes(uint256 size) internal pure returns (bytes memory) {
        bytes memory data = new bytes(size);
        for (uint256 i = 0; i < size; i++) {
            data[i] = bytes1(uint8(i % 256));
        }
        return data;
    }

    function _generateLargeBytesArray(uint256 size) internal pure returns (bytes[] memory) {
        bytes[] memory array = new bytes[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = _generateLargeBytes(100 + i);
        }
        return array;
    }

    // ============ EXISTING REVERT TESTS ============

    function test_RevertWhen_DappIDIsZero() public {
        bytes memory data = abi.encodeWithSignature("test()");
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "_toChainID";

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_IsZero.selector, C3ErrorParam.DAppID));
        c3caller.c3call(0, to, toChainID, data);
    }

    function test_RevertWhen_ToAddressIsEmpty() public {
        bytes memory data = abi.encodeWithSignature("test()");
        string memory to = "";
        string memory toChainID = "_toChainID";

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.To));
        c3caller.c3call(1, to, toChainID, data);
    }

    function test_RevertWhen_ChainIDIsEmpty() public {
        bytes memory data = abi.encodeWithSignature("test()");
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "";

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.ChainID));
        c3caller.c3call(1, to, toChainID, data);
    }

    function test_RevertWhen_DataIsEmpty() public {
        bytes memory data = "";
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "_toChainID";

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.Calldata));
        c3caller.c3call(1, to, toChainID, data);
    }
}
