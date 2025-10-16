// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {C3Governor} from "../../src/gov/C3Governor.sol";
import {IC3Governor} from "../../src/gov/IC3Governor.sol";

import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";
import {MockGovernedDApp} from "../helpers/mocks/MockGovernedDApp.sol";
import {Helpers} from "../helpers/Helpers.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {C3Caller} from "../../src/C3Caller.sol";
import {IC3Caller} from "../../src/IC3Caller.sol";
import {IC3CallerDApp} from "../../src/dapp/IC3CallerDApp.sol";
import {IC3GovernDApp} from "../../src/gov/IC3GovernDApp.sol";
import {TestGovernor} from "../helpers/mocks/TestGovernor.sol";

// TODO: Add tests for C3Governor
contract C3GovernorTest is Helpers {
    using Strings for *;

    C3Governor public c3Governor;
    TestGovernor public testGovernor;
    C3UUIDKeeper public c3UUIDKeeper;
    C3Caller public c3Caller;
    MockGovernedDApp public mockGovernedDApp;

    uint256 public testDAppID = 123;
    bytes32 public testProposalId = keccak256("test-proposal");

    // Test data for cross-chain calls
    string[] private testChainIds = ["1", "137", "421614", "10", "56"]; // Ethereum, Polygon, Arbitrum, Optimism, BSC

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
    function getTestChainId(uint256 index) internal view returns (string memory) {
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

        // Deploy TestGovernor
        testGovernor = new TestGovernor("TestGovernor", IVotes(address(ctm)), 4, 1, 50400, 0);

        // Deploy C3Governor with gov as the governance contract
        c3Governor = new C3Governor(
            gov, // Use gov as the governance contract
            address(c3Caller),
            user1, // Use user1 as txSender like in C3GovernDApp test
            testDAppID
        );

        mockGovernedDApp = new MockGovernedDApp(address(c3Governor));

        c3Governor.setPeer("1",     "0xaabbccddaabbccddaabbccddaabbccddaabbccdd");
        c3Governor.setPeer("10",    "0xbbccddeebbccddeebbccddeebbccddeebbccddee");
        c3Governor.setPeer("56",    "0xccddeeffccddeeffccddeeffccddeeffccddeeff");
        c3Governor.setPeer("137",   "0xddeeff00ddeeff00ddeeff00ddeeff00ddeeff00");
        c3Governor.setPeer("421614", "0xeeff0011eeff0011eeff0011eeff0011eeff0011");

        vm.stopPrank();
    }

    // INFO: test sendParams pass case
    function test_sendParams_EmitsCorrectEvents() public {
        uint256 nonce = uint256(keccak256("test-send-params"));

        string[] memory targets = new string[](5);
        string[] memory toChainIds = new string[](5);
        bytes[] memory datas = new bytes[](5);

        for (uint8 i = 0; i < 5; i++) {
            targets[i] = getTestTarget(i);
            toChainIds[i] = getTestChainId(i);
            datas[i] = getTestCalldata(i);
        }

        uint256 c3Nonce = c3UUIDKeeper.currentNonce();

        bytes[] memory destChainDatas = new bytes[](5);
        bytes32[] memory expectedUUIDs = new bytes32[](5);
        string[] memory peers = new string[](5);

        for (uint8 i = 0; i < 5; i++) {
            peers[i] = c3Governor.peer(toChainIds[i]);
            destChainDatas[i] = abi.encodeWithSelector(
                IC3Governor.receiveParams.selector, nonce, i, targets[i], toChainIds[i], datas[i]
            );
            expectedUUIDs[i] = c3UUIDKeeper.calcCallerUUIDWithNonce(
                address(c3Caller), testDAppID, peers[i], toChainIds[i], destChainDatas[i], c3Nonce + i + 1
            );
        }

        // Call sendParams directly (not through governance)
        vm.startPrank(gov);
        for (uint8 i = 0; i < 5; i++) {
            // C3Governor local event should emit
            vm.expectEmit(true, true, false, true);
            emit IC3Caller.LogC3Call(
                testDAppID, expectedUUIDs[i], address(c3Governor), toChainIds[i], peers[i], destChainDatas[i], ""
            );

            // C3Caller relayer event should emit
            vm.expectEmit(true, false, false, true);
            emit IC3Governor.C3GovernorCall(nonce, i, targets[i], toChainIds[i], datas[i]);
        }
        c3Governor.sendParams(nonce, targets, toChainIds, datas);
        vm.stopPrank();
    }

    // INFO: test input validation measures in sendParams
    function test_sendParams_InputValidation() public {
        uint256 nonce = uint256(keccak256("validation-test"));

        // Test 1: Only governance can call sendParams
        vm.prank(user1); // user1 is not governance
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrC3Caller
            )
        );
        c3Governor.sendParams(nonce, new string[](1), new string[](1), new bytes[](1));

        // Test 2: Proposal already registered
        string[] memory validTargets = new string[](1);
        string[] memory validChainIds = new string[](1);
        bytes[] memory validDatas = new bytes[](1);
        validTargets[0] = getTestTarget(0);
        validChainIds[0] = getTestChainId(0);
        validDatas[0] = getTestCalldata(0);
        vm.startPrank(gov);
        c3Governor.sendParams(nonce, validTargets, validChainIds, validDatas);
        vm.stopPrank();
        // Try to send same proposal again
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidProposal.selector, nonce));
        c3Governor.sendParams(nonce, new string[](1), new string[](1), new bytes[](1));

        // Use new nonce for remaining tests
        nonce = uint256(keccak256("validation-test-2"));

        // Test 3: Empty arrays (length == 0)
        vm.startPrank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidLength.selector, C3ErrorParam.To));
        c3Governor.sendParams(nonce, new string[](0), new string[](1), new bytes[](1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3Governor.C3Governor_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.ChainID
            )
        );
        c3Governor.sendParams(nonce, new string[](1), new string[](0), new bytes[](1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3Governor.C3Governor_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.Calldata
        ));
        c3Governor.sendParams(nonce, new string[](1), new string[](1), new bytes[](0));

        // Test 4: Length mismatch - targets vs chainIds
        string[] memory targets = new string[](2);
        string[] memory chainIds = new string[](1);
        bytes[] memory calldatas = new bytes[](2);

        targets[0] = getTestTarget(0);
        targets[1] = getTestTarget(1);
        chainIds[0] = getTestChainId(0);
        calldatas[0] = getTestCalldata(0);
        calldatas[1] = getTestCalldata(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IC3Governor.C3Governor_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.ChainID
            )
        );
        c3Governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 5: Length mismatch - targets vs calldatas
        chainIds = new string[](2);
        chainIds[0] = getTestChainId(0);
        chainIds[1] = getTestChainId(1);
        calldatas = new bytes[](1);
        calldatas[0] = getTestCalldata(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IC3Governor.C3Governor_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.Calldata
            )
        );
        c3Governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 6: Empty target string
        targets = new string[](1);
        chainIds = new string[](1);
        calldatas = new bytes[](1);

        targets[0] = ""; // Empty target
        chainIds[0] = getTestChainId(0);
        calldatas[0] = getTestCalldata(0);

        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidLength.selector, C3ErrorParam.To));
        c3Governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 7: Unsupported chain ID
        nonce = uint256(keccak256("validation-test-3"));
        targets[0] = getTestTarget(0);
        chainIds[0] = "999999"; // Unsupported chain ID
        calldatas[0] = getTestCalldata(0);

        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_UnsupportedChainID.selector, "999999"));
        c3Governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 8: Empty calldata
        nonce = uint256(keccak256("validation-test-4"));
        targets[0] = getTestTarget(0);
        chainIds[0] = getTestChainId(0);
        calldatas[0] = ""; // Empty calldata

        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidLength.selector, C3ErrorParam.Calldata));
        c3Governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 9: Multiple validation failures in array (test first failure)
        nonce = uint256(keccak256("validation-test-5"));
        targets = new string[](3);
        chainIds = new string[](3);
        calldatas = new bytes[](3);

        targets[0] = getTestTarget(0);
        targets[1] = ""; // Empty target (should fail first)
        targets[2] = getTestTarget(2);
        chainIds[0] = getTestChainId(0);
        chainIds[1] = getTestChainId(1);
        chainIds[2] = "999999"; // Unsupported chain ID
        calldatas[0] = getTestCalldata(0);
        calldatas[1] = getTestCalldata(1);
        calldatas[2] = getTestCalldata(2);

        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidLength.selector, C3ErrorParam.To));
        c3Governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 10: Valid input should succeed
        nonce = uint256(keccak256("validation-test-6"));
        targets[0] = getTestTarget(0);
        targets[1] = getTestTarget(1);
        targets[2] = getTestTarget(2);
        chainIds[0] = getTestChainId(0);
        chainIds[1] = getTestChainId(1);
        chainIds[2] = getTestChainId(2);
        calldatas[0] = getTestCalldata(0);
        calldatas[1] = getTestCalldata(1);
        calldatas[2] = getTestCalldata(2);

        // Should not revert
        c3Governor.sendParams(nonce, targets, chainIds, calldatas);
        vm.stopPrank();
    }

    // INFO: test fallback mechanism when cross-chain calls fail
    function test_Fallback_EmitsCorrectEvents() public {
        uint256 nonce = uint256(keccak256("cross-chain-tx"));
        uint256 index = 0;
        string memory target = address(mockGovernedDApp).toHexString();
        string memory toChainId = getTestChainId(0);
        bytes memory data = abi.encodeWithSelector(MockGovernedDApp.sensitiveNumberChange.selector, 1);

        bytes memory destChainData = abi.encodeWithSelector(
            C3Governor.receiveParams.selector, nonce, index, target, toChainId, data
        );

        bytes memory revertData =
            abi.encodeWithSelector(IC3Governor.C3Governor_ExecFailed.selector, "Target contract revert data");
        bytes memory reason = bytes("Target contract revert data");

        // NOTE: only C3Caller is able to call c3Fallback on C3CallerDApp
        vm.prank(address(c3Caller));
        vm.expectEmit(true, false, false, true);
        emit IC3Governor.C3GovernorFallback(nonce, 0, target, toChainId, data, reason);
        c3Governor.c3Fallback(testDAppID, destChainData, revertData);

        (string memory failedTarget, string memory failedToChainId, bytes memory failedData) =
            c3Governor.failed(nonce, 0);
        assertEq(failedTarget, target);
        assertEq(failedToChainId, toChainId);
        assertEq(failedData, data);
    }

    // INFO: test doGov - any user can re-execute failed proposal indices
    function test_doGov_EmitsCorrectEvents() public {
        // setup the proposal call for dest chain
        uint256 nonce = uint256(keccak256("cross-chain-failed-tx"));
        uint256 index = 27;
        string memory toChainId = getTestChainId(0);

        // get the peer for the given dest chain
        string memory peer = c3Governor.peer(toChainId);

        // sendParams to make nonce valid in C3Governor
        string[] memory targets = new string[](1);
        string[] memory toChainIds = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = address(mockGovernedDApp).toHexString();
        toChainIds[0] = toChainId;
        datas[0] = abi.encodeWithSelector(MockGovernedDApp.sensitiveNumberChange.selector, 1);

        vm.prank(gov);
        c3Governor.sendParams(nonce, targets, toChainIds, datas);

        bytes memory destChainData = abi.encodeWithSelector(
            C3Governor.receiveParams.selector, nonce, index, targets[0], toChainIds[0], datas[0]
        );

        bytes memory revertData =
            abi.encodeWithSelector(IC3Governor.C3Governor_ExecFailed.selector, "Target contract revert data");

        vm.prank(address(c3Caller));
        c3Governor.c3Fallback(testDAppID, destChainData, revertData);

        bytes32 expectedUUID = c3UUIDKeeper.calcCallerUUID(
            address(c3Caller), testDAppID, peer, toChainId, destChainData
        );
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(testDAppID, expectedUUID, address(c3Governor), toChainId, peer, destChainData, "");
        c3Governor.doGov(nonce, index);

        // should fail the second time for the same nonce & index
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_HasNotFailed.selector));
        c3Governor.doGov(nonce, index);
    }

    // INFO: test doGov for non-existent proposal
    function test_doGov_NonExistentProposal() public {
        uint256 nonce = uint256(keccak256("non-existent-proposalid"));
        uint256 index = 0;
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidProposal.selector, nonce));
        c3Governor.doGov(nonce, index);
    }

    // INFO: test retrying an existing non-failed proposal using doGov
    function test_doGov_NonFailedProposal() public {
        uint256 nonce = uint256(keccak256("test-do-gov-passed-proposal"));
        uint256 index = 33;
        string[] memory targets = new string[](1);
        string[] memory toChainIds = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = getTestTarget(0);
        toChainIds[0] = getTestChainId(0);
        datas[0] = getTestCalldata(0);
        vm.prank(gov);
        c3Governor.sendParams(nonce, targets, toChainIds, datas);
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_HasNotFailed.selector));
        c3Governor.doGov(nonce, index);
    }

    // INFO: test receiveParams executes successful proposal on dest chain
    function test_receiveParams_EmitsCorrectEvents() public {
        uint256 nonce = uint256(keccak256("test-cross-chain-proposalid"));
        uint256 index = 9;
        uint256 setNum = 2001;
        address targetAddr = address(mockGovernedDApp);
        string[] memory targets = new string[](1);
        string[] memory toChainIds = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = targetAddr.toHexString();
        toChainIds[0] = getTestChainId(0);
        datas[0] = abi.encodeWithSelector(MockGovernedDApp.sensitiveNumberChange.selector, setNum);
        vm.prank(address(c3Caller));
        vm.expectEmit(true, false, false, true);
        emit IC3Governor.C3GovernorExec(nonce, index, targets[0], toChainIds[0], datas[0]);
        bytes memory result = c3Governor.receiveParams(nonce, index, targets[0], toChainIds[0], datas[0]);
        uint256 resultUint = abi.decode(result, (uint256));
        assertEq(resultUint, setNum);
    }

    // INFO: test receiveParams where the call reverts
    function test_receiveParams_CallFails() public {
        uint256 nonce = uint256(keccak256("test-failed-cross-chain-proposal"));
        uint256 index = 1;
        uint256 setNum = 2025;
        address targetAddr = address(mockGovernedDApp);
        string[] memory targets = new string[](1);
        string[] memory toChainIds = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = targetAddr.toHexString();
        toChainIds[0] = getTestChainId(0);
        datas[0] = abi.encodeWithSelector(mockGovernedDApp.sensitiveNumberChange.selector, setNum);
        bytes memory brokenResult = abi.encodeWithSelector(MockGovernedDApp.Broken.selector, setNum);
        vm.prank(address(c3Caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_ExecFailed.selector, brokenResult));
        c3Governor.receiveParams(nonce, index, targets[0], toChainIds[0], datas[0]);
    }

    // INFO: test fallback with any selector other than receiveParams
    function test_c3Fallback_WrongSelector() public {
        uint256 nonce = uint256(keccak256("wrong-selector-call"));
        uint256 index = 47;
        vm.prank(address(c3Caller));
        bytes memory wrongSelectorData = abi.encodeWithSelector(IC3Governor.doGov.selector, nonce, index);
        bool result = c3Governor.c3Fallback(testDAppID, wrongSelectorData, "");
        assertFalse(result);
    }
}
