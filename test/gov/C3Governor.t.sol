// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3Governor} from "../../src/gov/C3Governor.sol";
import {IC3Governor} from "../../src/gov/IC3Governor.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";
import {MockC3GovernDApp} from "../helpers/mocks/MockC3GovernDApp.sol";
import {Helpers} from "../helpers/Helpers.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {C3Caller} from "../../src/C3Caller.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TestGovernor} from "../helpers/mocks/TestGovernor.sol";
import {console} from "forge-std/console.sol";

// TODO: Add tests for C3Governor
contract C3GovernorTest is Helpers {
    C3Governor public c3Governor;
    TestGovernor public testGovernor;
    C3UUIDKeeper public c3UUIDKeeper;
    C3Caller public c3Caller;
    MockC3GovernDApp public mockC3GovernDApp;
    
    uint256 public testDAppID = 123;
    bytes32 public testProposalId = keccak256("test-proposal");
    
    // Test data for cross-chain calls
    uint256[] private testChainIds = [1, 137, 42161, 10, 56]; // Ethereum, Polygon, Arbitrum, Optimism, BSC
    string[] private testTargets = [
        "0x1234567890123456789012345678901234567890",
        "0x2345678901234567890123456789012345678901", 
        "0x3456789012345678901234567890123456789012",
        "0x4567890123456789012345678901234567890123",
        "0x5678901234567890123456789012345678901234"
    ];
    bytes[] private testCalldata = [
        abi.encodeWithSignature("transfer(address,uint256)", address(0x123), 1000),
        abi.encodeWithSignature("mint(address,uint256)", address(0x456), 500),
        abi.encodeWithSignature("burn(uint256)", 123),
        abi.encodeWithSignature("approve(address,uint256)", address(0x789), 2000),
        abi.encodeWithSignature("transferFrom(address,address,uint256)", address(0xabc), address(0xdef), 750)
    ];

    // Helper function to safely access test data
    function getTestChainId(uint256 index) internal view returns (uint256) {
        require(index < testChainIds.length, "Index out of bounds");
        return testChainIds[index];
    }

    function getTestTarget(uint256 index) internal view returns (string memory) {
        require(index < testTargets.length, "Index out of bounds");
        return testTargets[index];
    }

    function getTestCalldata(uint256 index) internal view returns (bytes memory) {
        require(index < testCalldata.length, "Index out of bounds");
        return testCalldata[index];
    }

    function setUp() public virtual override {
        super.setUp();

        // Deploy C3UUIDKeeper and C3Caller
        vm.startPrank(gov);
        c3UUIDKeeper = new C3UUIDKeeper();
        c3Caller = new C3Caller(address(c3UUIDKeeper));
        
        // Add operator permissions
        c3UUIDKeeper.addOperator(address(c3Caller));
        c3Caller.addOperator(gov);
        c3Caller.addOperator(mpc1);
        vm.stopPrank();

        // Deploy TestGovernor
        testGovernor = new TestGovernor("TestGovernor", IVotes(address(ctm)), 4, 1, 50400, 0);

        // Deploy C3Governor with gov as the governance contract
        c3Governor = new C3Governor(
            gov, // Use gov as the governance contract
            address(c3Caller),
            user1, // Use user1 as txSender like in C3GovernDApp test
            testDAppID
        );

        // Deploy mock C3GovernDApp for comparison
        mockC3GovernDApp = new MockC3GovernDApp(
            gov, // Use gov as the governance contract
            address(c3Caller),
            user1, // Use user1 as txSender
            testDAppID
        );
    }

    // Test for sendParams functionality
    function test_sendParams_EmitsCorrectEvents() public {
        bytes32 nonce = keccak256("test-send-params");
        bytes memory testData = abi.encode(
            getTestChainId(0), // chainId
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );

        // Call sendParams directly (not through governance)
        vm.startPrank(gov);
        c3Governor.sendParams(testData, nonce);
        vm.stopPrank();

        // Verify the proposal was created
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(storedData, testData, "Stored data should match input data");
        assertEq(hasFailed, true, "Cross-chain proposal should be marked as failed after execution");
    }

    // Test for sendMultiParams functionality
    function test_sendMultiParams_EmitsCorrectEvents() public {
        bytes32 nonce = keccak256("test-send-multi-params");
        bytes[] memory testDataArray = new bytes[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            testDataArray[i] = abi.encode(
                getTestChainId(i), // chainId
                getTestTarget(i),   // target
                getTestCalldata(i)  // calldata
            );
        }

        // Call sendMultiParams directly (not through governance)
        vm.startPrank(gov);
        c3Governor.sendMultiParams(testDataArray, nonce);
        vm.stopPrank();

        // Verify all proposals were created
        for (uint256 i = 0; i < 3; i++) {
            (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, i);
            assertEq(storedData, testDataArray[i], "Stored data should match input data");
            assertEq(hasFailed, true, "Cross-chain proposals should be marked as failed after execution");
        }
    }

    // Test that mockC3GovernDApp can use C3Governor to call sendParams
    function test_mockC3GovernDApp_uses_C3Governor_sendParams() public {
        bytes32 nonce = keccak256("mock-dapp-send-params");
        bytes memory testData = abi.encode(
            getTestChainId(1), // chainId
            getTestTarget(1),   // target
            getTestCalldata(1)  // calldata
        );

        // Set up the mock dapp to call C3Governor
        vm.startPrank(gov);
        
        // First, add the mock dapp as a valid transaction sender
        mockC3GovernDApp.addTxSender(address(mockC3GovernDApp));
        
        // Call sendParams directly
        c3Governor.sendParams(testData, nonce);
        vm.stopPrank();

        // Verify the proposal was created correctly
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(storedData, testData, "Stored data should match input data");
        assertEq(hasFailed, true, "Cross-chain proposal should be marked as failed after execution");
    }

    // Test that mockC3GovernDApp can use C3Governor to call sendMultiParams
    function test_mockC3GovernDApp_uses_C3Governor_sendMultiParams() public {
        bytes32 nonce = keccak256("mock-dapp-send-multi-params");
        bytes[] memory testDataArray = new bytes[](2);
        
        for (uint256 i = 0; i < 2; i++) {
            testDataArray[i] = abi.encode(
                getTestChainId(i + 2), // chainId
                getTestTarget(i + 2),   // target
                getTestCalldata(i + 2)  // calldata
            );
        }

        // Set up the mock dapp to call C3Governor
        vm.startPrank(gov);
        
        // First, add the mock dapp as a valid transaction sender
        mockC3GovernDApp.addTxSender(address(mockC3GovernDApp));
        
        // Call sendMultiParams directly
        c3Governor.sendMultiParams(testDataArray, nonce);
        vm.stopPrank();

        // Verify all proposals were created correctly
        for (uint256 i = 0; i < 2; i++) {
            (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, i);
            assertEq(storedData, testDataArray[i], "Stored data should match input data");
            assertEq(hasFailed, true, "Cross-chain proposals should be marked as failed after execution");
        }
    }

    // Test cross-chain proposal execution and event emission
    function test_crossChainProposal_execution_and_events() public {
        bytes32 nonce = keccak256("cross-chain-proposal");
        
        // Create test data for a cross-chain call
        uint256 targetChainId = getTestChainId(0);
        string memory targetAddress = getTestTarget(0);
        bytes memory targetCalldata = getTestCalldata(0);
        
        bytes memory testData = abi.encode(targetChainId, targetAddress, targetCalldata);

        vm.startPrank(gov);
        
        // Call sendParams directly
        c3Governor.sendParams(testData, nonce);
        vm.stopPrank();

        // Verify the proposal was created and marked as failed (since it's cross-chain)
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(storedData, testData, "Stored data should match input data");
        assertEq(hasFailed, true, "Cross-chain proposal should be marked as failed initially");
    }

    // Test multiple cross-chain proposals in a single call
    function test_multipleCrossChainProposals_execution_and_events() public {
        bytes32 nonce = keccak256("multiple-cross-chain-proposals");
        bytes[] memory testDataArray = new bytes[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            testDataArray[i] = abi.encode(
                getTestChainId(i), // chainId
                getTestTarget(i),   // target
                getTestCalldata(i)  // calldata
            );
        }

        vm.startPrank(gov);
        
        // Call sendMultiParams directly
        c3Governor.sendMultiParams(testDataArray, nonce);
        vm.stopPrank();

        // Verify all proposals were created and marked as failed
        for (uint256 i = 0; i < 3; i++) {
            (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, i);
            assertEq(storedData, testDataArray[i], "Stored data should match input data");
            assertEq(hasFailed, true, "Cross-chain proposals should be marked as failed initially");
        }
    }

    // Test fallback mechanism when cross-chain calls fail
    function test_fallback_mechanism_for_failed_calls() public {
        bytes32 nonce = keccak256("fallback-test");
        bytes memory testData = abi.encode(
            getTestChainId(0), // chainId
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );

        vm.startPrank(gov);
        
        // Call sendParams directly
        c3Governor.sendParams(testData, nonce);
        vm.stopPrank();

        // Simulate a failed cross-chain call by calling the fallback
        bytes memory fallbackData = abi.encode("test data");
        bytes memory reason = abi.encode("Cross-chain call failed");
        
        // Call the fallback function as C3Caller
        vm.prank(address(c3Caller));
        bool result = c3Governor.c3Fallback(testDAppID, fallbackData, reason);
        assertTrue(result, "Fallback should return true");
    }

    // Test that mockC3GovernDApp can handle fallbacks correctly
    function test_mockC3GovernDApp_fallback_handling() public {
        // Set up the mock dapp to revert
        mockC3GovernDApp.setShouldRevert(true);
        
        bytes memory fallbackData = abi.encode("mock dapp test data");
        bytes memory reason = abi.encode("Mock dapp intentional revert");
        
        // Expect the mock dapp to revert
        vm.expectRevert("MockC3GovernDApp: intentional revert");
        vm.prank(address(c3Caller));
        mockC3GovernDApp.c3Fallback(testDAppID, fallbackData, reason);
        
        // Set the mock dapp to not revert
        mockC3GovernDApp.setShouldRevert(false);
        
        // Now the fallback should succeed
        vm.prank(address(c3Caller));
        bool result = mockC3GovernDApp.c3Fallback(testDAppID, fallbackData, reason);
        assertTrue(result, "Mock dapp fallback should return true when not reverting");
    }

    // Test proposal length tracking
    function test_proposalLength_tracking() public {
        bytes32 nonce = keccak256("length-test");
        bytes[] memory testDataArray = new bytes[](5);
        
        for (uint256 i = 0; i < 5; i++) {
            testDataArray[i] = abi.encode(
                getTestChainId(i), // chainId
                getTestTarget(i),   // target
                getTestCalldata(i)  // calldata
            );
        }

        vm.startPrank(gov);
        
        // Call sendMultiParams directly
        c3Governor.sendMultiParams(testDataArray, nonce);
        vm.stopPrank();

        // Verify that all 5 proposals were created by checking each one
        for (uint256 i = 0; i < 5; i++) {
            (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, i);
            assertGt(storedData.length, 0, "Proposal data should exist");
        }
    }

    // Test that shows the correct initial and final states
    function test_proposal_initial_and_final_states() public {
        bytes32 nonce = keccak256("state-test");
        
        // Create test data for same-chain call (using current chain ID)
        uint256 currentChainId = block.chainid;
        bytes memory sameChainData = abi.encode(
            currentChainId, // Same chain ID
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );
        
        // Create test data for cross-chain call
        bytes memory crossChainData = abi.encode(
            getTestChainId(0), // Different chain ID
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );

        vm.startPrank(gov);
        
        // Test same-chain proposal
        c3Governor.sendParams(sameChainData, keccak256("same-chain"));
        
        // Test cross-chain proposal
        c3Governor.sendParams(crossChainData, keccak256("cross-chain"));
        vm.stopPrank();

        // Verify same-chain proposal (should remain false if call succeeds)
        (bytes memory sameChainStoredData, bool sameChainHasFailed) = c3Governor.getProposalData(keccak256("same-chain"), 0);
        assertEq(sameChainStoredData, sameChainData, "Same-chain data should match");
        assertEq(sameChainHasFailed, false, "Successful same-chain proposal should not be marked as failed");
        
        // Verify cross-chain proposal (should be true because it's cross-chain)
        (bytes memory crossChainStoredData, bool crossChainHasFailed) = c3Governor.getProposalData(keccak256("cross-chain"), 0);
        assertEq(crossChainStoredData, crossChainData, "Cross-chain data should match");
        assertEq(crossChainHasFailed, true, "Cross-chain proposal should be marked as failed");
    }

    // Test doGov functionality - any user can re-execute failed proposals
    function test_doGov_any_user_can_re_execute_failed_proposal() public {
        bytes32 nonce = keccak256("do-gov-test");
        bytes memory testData = abi.encode(
            getTestChainId(0), // chainId
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );

        // First, create a proposal that will fail (cross-chain)
        vm.startPrank(gov);
        c3Governor.sendParams(testData, nonce);
        vm.stopPrank();

        // Verify the proposal was created and marked as failed
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(storedData, testData, "Stored data should match input data");
        assertEq(hasFailed, true, "Cross-chain proposal should be marked as failed");

        // Any user should be able to re-execute the failed proposal
        vm.startPrank(user1); // Regular user
        c3Governor.doGov(nonce, 0);
        vm.stopPrank();

        // The proposal should still be marked as failed (since it's cross-chain)
        (storedData, hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(hasFailed, true, "Cross-chain proposal should remain failed after re-execution");
    }

    // Test doGov with multiple failed proposals
    function test_doGov_multiple_failed_proposals() public {
        bytes32 nonce = keccak256("do-gov-multi-test");
        bytes[] memory testDataArray = new bytes[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            testDataArray[i] = abi.encode(
                getTestChainId(i), // chainId
                getTestTarget(i),   // target
                getTestCalldata(i)  // calldata
            );
        }

        // First, create multiple proposals that will fail (cross-chain)
        vm.startPrank(gov);
        c3Governor.sendMultiParams(testDataArray, nonce);
        vm.stopPrank();

        // Verify all proposals were created and marked as failed
        for (uint256 i = 0; i < 3; i++) {
            (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, i);
            assertEq(storedData, testDataArray[i], "Stored data should match input data");
            assertEq(hasFailed, true, "Cross-chain proposals should be marked as failed");
        }

        // Any user should be able to re-execute any of the failed proposals
        vm.startPrank(user2); // Different user
        c3Governor.doGov(nonce, 1); // Re-execute the second proposal
        vm.stopPrank();

        // The re-executed proposal should still be marked as failed
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 1);
        assertEq(hasFailed, true, "Cross-chain proposal should remain failed after re-execution");
    }

    // Test doGov with successful same-chain proposal (should NOT be marked as failed)
    function test_doGov_successful_same_chain_proposal() public {
        bytes32 nonce = keccak256("do-gov-successful-test");
        
        // Create a same-chain proposal that will succeed (so it should NOT be marked as failed)
        uint256 currentChainId = block.chainid;
        bytes memory sameChainData = abi.encode(
            currentChainId, // Same chain ID
            "0x0000000000000000000000000000000000000001",   // target (use a valid hex string)
            abi.encodeWithSignature("version()")  // calldata (call a function that exists)
        );

        vm.startPrank(gov);
        c3Governor.sendParams(sameChainData, nonce);
        vm.stopPrank();

        // Verify the proposal was NOT marked as failed (because the call succeeded)
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(storedData, sameChainData, "Stored data should match input data");
        assertEq(hasFailed, false, "Successful same-chain proposal should not be marked as failed");

        // Try to re-execute a non-failed proposal - should revert
        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with C3Governor_HasNotFailed
        c3Governor.doGov(nonce, 0);
        vm.stopPrank();
    }

    // Test doGov with cross-chain proposal (should be marked as failed and can be re-executed)
    function test_doGov_cross_chain_proposal() public {
        bytes32 nonce = keccak256("do-gov-cross-chain-test");
        
        // Create a cross-chain proposal (should be marked as failed)
        bytes memory crossChainData = abi.encode(
            getTestChainId(0), // Different chain ID
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );

        vm.startPrank(gov);
        c3Governor.sendParams(crossChainData, nonce);
        vm.stopPrank();

        // Verify the proposal was marked as failed (because it's cross-chain)
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(storedData, crossChainData, "Stored data should match input data");
        assertEq(hasFailed, true, "Cross-chain proposal should be marked as failed");

        // Now try to re-execute the failed proposal - should work
        vm.startPrank(user1);
        c3Governor.doGov(nonce, 0);
        vm.stopPrank();

        // The proposal should still be marked as failed
        (storedData, hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(hasFailed, true, "Proposal should remain failed after re-execution");
    }



    // Test doGov with out of bounds offset should revert
    function test_doGov_out_of_bounds_reverts() public {
        bytes32 nonce = keccak256("do-gov-bounds-test");
        bytes memory testData = abi.encode(
            getTestChainId(0), // chainId
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );

        // Create a proposal
        vm.startPrank(gov);
        c3Governor.sendParams(testData, nonce);
        vm.stopPrank();

        // Try to re-execute with out of bounds offset - should revert
        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with C3Governor_OutOfBounds
        c3Governor.doGov(nonce, 1); // Offset 1 doesn't exist
        vm.stopPrank();
    }

    // Test doGov with non-existent proposal should revert
    function test_doGov_non_existent_proposal_reverts() public {
        bytes32 nonce = keccak256("non-existent-proposal");
        
        // Try to re-execute a non-existent proposal - should revert
        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with C3Governor_OutOfBounds
        c3Governor.doGov(nonce, 0);
        vm.stopPrank();
    }

    // Test doGov events are emitted correctly
    function test_doGov_emits_correct_events() public {
        bytes32 nonce = keccak256("do-gov-events-test");
        bytes memory testData = abi.encode(
            getTestChainId(0), // chainId
            getTestTarget(0),   // target
            getTestCalldata(0)  // calldata
        );

        // Create a proposal that will fail
        vm.startPrank(gov);
        c3Governor.sendParams(testData, nonce);
        vm.stopPrank();

        // Re-execute the failed proposal and expect C3GovernorLog event
        vm.startPrank(user1);
        c3Governor.doGov(nonce, 0);
        vm.stopPrank();

        // Verify the proposal data is still correct
        (bytes memory storedData, bool hasFailed) = c3Governor.getProposalData(nonce, 0);
        assertEq(storedData, testData, "Stored data should match input data");
        assertEq(hasFailed, true, "Cross-chain proposal should remain failed after re-execution");
    }

    // Test error cases
    function test_sendParams_empty_data_reverts() public {
        bytes32 nonce = keccak256("empty-data-test");
        bytes memory emptyData = "";

        vm.startPrank(gov);
        
        // Expect revert for empty data
        vm.expectRevert();
        c3Governor.sendParams(emptyData, nonce);
        vm.stopPrank();
    }

    function test_sendMultiParams_empty_array_reverts() public {
        bytes32 nonce = keccak256("empty-array-test");
        bytes[] memory emptyArray = new bytes[](0);

        vm.startPrank(gov);
        
        // Expect revert for empty array
        vm.expectRevert();
        c3Governor.sendMultiParams(emptyArray, nonce);
        vm.stopPrank();
    }

    function test_sendMultiParams_empty_data_in_array_reverts() public {
        bytes32 nonce = keccak256("empty-data-in-array-test");
        bytes[] memory testDataArray = new bytes[](2);
        testDataArray[0] = abi.encode(getTestChainId(0), getTestTarget(0), getTestCalldata(0));
        testDataArray[1] = ""; // Empty data

        vm.startPrank(gov);
        
        // Expect revert for empty data in array
        vm.expectRevert();
        c3Governor.sendMultiParams(testDataArray, nonce);
        vm.stopPrank();
    }
}
