// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {C3Governor} from "../../src/gov/C3Governor.sol";
import {IC3Governor} from "../../src/gov/IC3Governor.sol";

import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";
import {MockC3GovernDApp} from "../mocks/MockC3GovernDApp.sol";
import {Helpers} from "../helpers/Helpers.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {C3Caller} from "../../src/C3Caller.sol";
import {IC3Caller} from "../../src/IC3Caller.sol";
import {IC3CallerDApp} from "../../src/dapp/IC3CallerDApp.sol";
import {IC3GovernDApp} from "../../src/gov/IC3GovernDApp.sol";
import {TestGovernor} from "../mocks/MockGovernor.sol";
import {MockC3GovClient} from "../mocks/MockC3GovClient.sol";

// TODO: Add tests for C3Governor
contract C3GovernorTest is Helpers {
    using Strings for *;

    C3Governor public c3governor;
    TestGovernor public testGovernor;
    MockC3GovernDApp public mockC3GovernDApp;

    uint256 public c3governorDAppID;
    uint256 public mockDAppID;
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

        // Deploy C3UUIDKeeper, C3DAppManager and C3Caller
        _deployC3UUIDKeeper(gov);
        _deployC3DAppManager(gov);
        _deployC3Caller(gov);

        // Set C3Caller address in UUIDKeeper and DAppManager
        _setC3Caller(gov);

        // Set USDC and CTM as valid fee tokens
        _setFeeConfig(gov, address(usdc));
        _setFeeConfig(gov, address(ctm));

        string memory dappKey = "v1.c3governor.c3caller";
        string memory metadata =
            "{'version':1,'name':'C3Governor','description':'Cross-chain governance','email':'admin@c3gov.com','url':'c3gov.com'}";

        c3governorDAppID = _initDAppConfig(gov, dappKey, address(usdc), metadata);

        vm.prank(gov);
        usdc.approve(address(dappManager), type(uint256).max);

        // Deploy C3Governor with gov as the governance contract
        c3governor = new C3Governor(
            gov, // Use gov as the governance contract
            address(c3caller),
            c3governorDAppID
        );
        vm.startPrank(gov);
        dappManager.setDAppAddr(c3governorDAppID, address(c3governor), true);
        dappManager.deposit(c3governorDAppID, address(usdc), 100 * 10 ** usdc.decimals());
        vm.stopPrank();

        // Deploy TestGovernor
        testGovernor = new TestGovernor("TestGovernor", IVotes(address(ctm)), 4, 1, 50400, 0);

        vm.startPrank(gov);
        c3caller.activateChainID("1");
        c3caller.activateChainID("10");
        c3caller.activateChainID("56");
        c3caller.activateChainID("137");
        c3caller.activateChainID("421614");
        c3governor.setPeer("1", "0xaabbccddaabbccddaabbccddaabbccddaabbccdd");
        c3governor.setPeer("10", "0xbbccddeebbccddeebbccddeebbccddeebbccddee");
        c3governor.setPeer("56", "0xccddeeffccddeeffccddeeffccddeeffccddeeff");
        c3governor.setPeer("137", "0xddeeff00ddeeff00ddeeff00ddeeff00ddeeff00");
        c3governor.setPeer("421614", "0xeeff0011eeff0011eeff0011eeff0011eeff0011");
        vm.stopPrank();

        string memory dappKeyMock = "v1.c3mock.c3caller";
        string memory metadataMock =
            "{'version':1,'name':'MockC3GovernDApp','description':'Mock description','email':'admin@c3mock.com','url':'c3mock.com'}";

        (mockC3GovernDApp, mockDAppID) =
            _createC3GovernDApp(gov, address(c3governor), dappKeyMock, address(usdc), metadataMock);
    }

    // =============================
    // ======== SEND PARAMS ========
    // =============================

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

        uint256 c3Nonce = uuidKeeper.currentNonce();

        bytes[] memory destChainDatas = new bytes[](5);
        bytes32[] memory expectedUUIDs = new bytes32[](5);
        string[] memory peers = new string[](5);

        for (uint8 i = 0; i < 5; i++) {
            peers[i] = c3governor.peer(toChainIds[i]);
            destChainDatas[i] = abi.encodeWithSelector(
                IC3Governor.receiveParams.selector, nonce, i, targets[i], toChainIds[i], datas[i]
            );
            expectedUUIDs[i] = uuidKeeper.calcCallerUUIDWithNonce(
                address(c3caller), c3governorDAppID, peers[i], toChainIds[i], destChainDatas[i], c3Nonce + i + 1
            );
        }

        // Call sendParams directly (not through governance)
        vm.startPrank(gov);
        for (uint8 i = 0; i < 5; i++) {
            // C3Governor local event should emit
            vm.expectEmit(true, true, false, true);
            emit IC3Caller.LogC3Call(
                c3governorDAppID, expectedUUIDs[i], address(c3governor), toChainIds[i], peers[i], destChainDatas[i], ""
            );

            // C3Caller relayer event should emit
            vm.expectEmit(true, false, false, true);
            emit IC3Governor.C3GovernorCall(nonce, i, targets[i], toChainIds[i], datas[i]);
        }
        c3governor.sendParams(nonce, targets, toChainIds, datas);
        vm.stopPrank();
    }

    // INFO: test input validation measures in sendParams
    function test_sendParams_InputValidation() public {
        uint256 nonce = uint256(keccak256("validation-test"));

        // Test 1: Only governance can call sendParams
        vm.prank(user1); // user1 is not governance
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        c3governor.sendParams(nonce, new string[](1), new string[](1), new bytes[](1));

        // Test 2: Proposal already registered
        string[] memory validTargets = new string[](1);
        string[] memory validChainIds = new string[](1);
        bytes[] memory validDatas = new bytes[](1);
        validTargets[0] = getTestTarget(0);
        validChainIds[0] = getTestChainId(0);
        validDatas[0] = getTestCalldata(0);
        vm.startPrank(gov);
        c3governor.sendParams(nonce, validTargets, validChainIds, validDatas);
        vm.stopPrank();
        // Try to send same proposal again
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidProposal.selector, nonce));
        c3governor.sendParams(nonce, new string[](1), new string[](1), new bytes[](1));

        // Use new nonce for remaining tests
        nonce = uint256(keccak256("validation-test-2"));

        // Test 3: Empty arrays (length == 0)
        vm.startPrank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidLength.selector, C3ErrorParam.To));
        c3governor.sendParams(nonce, new string[](0), new string[](1), new bytes[](1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3Governor.C3Governor_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.ChainID
            )
        );
        c3governor.sendParams(nonce, new string[](1), new string[](0), new bytes[](1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3Governor.C3Governor_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.Calldata
            )
        );
        c3governor.sendParams(nonce, new string[](1), new string[](1), new bytes[](0));

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
        c3governor.sendParams(nonce, targets, chainIds, calldatas);

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
        c3governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 6: Empty target string
        targets = new string[](1);
        chainIds = new string[](1);
        calldatas = new bytes[](1);

        targets[0] = ""; // Empty target
        chainIds[0] = getTestChainId(0);
        calldatas[0] = getTestCalldata(0);

        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidLength.selector, C3ErrorParam.To));
        c3governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 7: Unsupported chain ID
        nonce = uint256(keccak256("validation-test-3"));
        targets[0] = getTestTarget(0);
        chainIds[0] = "999999"; // Unsupported chain ID
        calldatas[0] = getTestCalldata(0);

        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_UnsupportedChainID.selector, "999999"));
        c3governor.sendParams(nonce, targets, chainIds, calldatas);

        // Test 8: Empty calldata
        nonce = uint256(keccak256("validation-test-4"));
        targets[0] = getTestTarget(0);
        chainIds[0] = getTestChainId(0);
        calldatas[0] = ""; // Empty calldata

        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidLength.selector, C3ErrorParam.Calldata));
        c3governor.sendParams(nonce, targets, chainIds, calldatas);

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
        c3governor.sendParams(nonce, targets, chainIds, calldatas);

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
        c3governor.sendParams(nonce, targets, chainIds, calldatas);
        vm.stopPrank();
    }

    // ========================
    // ======== DO GOV ========
    // ========================

    // INFO: test doGov - any user can re-execute failed proposal indices
    function test_doGov_EmitsCorrectEvents() public {
        // setup the proposal call for dest chain
        uint256 nonce = uint256(keccak256("cross-chain-failed-tx"));
        uint256 index = 27;
        string memory toChainId = getTestChainId(0);

        // get the peer for the given dest chain
        string memory peer = c3governor.peer(toChainId);

        // sendParams to make nonce valid in C3Governor
        string[] memory targets = new string[](1);
        string[] memory toChainIds = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = address(mockC3GovernDApp).toHexString();
        toChainIds[0] = toChainId;
        datas[0] = abi.encodeWithSelector(MockC3GovernDApp.mockC3ExecutableGov.selector, "Sensitive change");

        vm.prank(gov);
        c3governor.sendParams(nonce, targets, toChainIds, datas);

        bytes memory destChainData = abi.encodeWithSelector(
            C3Governor.receiveParams.selector, nonce, index, targets[0], toChainIds[0], datas[0]
        );

        bytes memory revertData =
            abi.encodeWithSelector(IC3Governor.C3Governor_ExecFailed.selector, "Target contract revert data");

        vm.prank(address(c3caller));
        c3governor.c3Fallback(c3governorDAppID, destChainData, revertData);

        bytes32 expectedUUID =
            uuidKeeper.calcCallerUUID(address(c3caller), c3governorDAppID, peer, toChainId, destChainData);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            c3governorDAppID, expectedUUID, address(c3governor), toChainId, peer, destChainData, ""
        );
        c3governor.doGov(nonce, index);

        // should fail the second time for the same nonce & index
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_HasNotFailed.selector));
        c3governor.doGov(nonce, index);
    }

    // INFO: test doGov for non-existent proposal
    function test_doGov_NonExistentProposal() public {
        uint256 nonce = uint256(keccak256("non-existent-proposalid"));
        uint256 index = 0;
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_InvalidProposal.selector, nonce));
        c3governor.doGov(nonce, index);
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
        c3governor.sendParams(nonce, targets, toChainIds, datas);
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_HasNotFailed.selector));
        c3governor.doGov(nonce, index);
    }

    // ================================
    // ======== RECEIVE PARAMS ========
    // ================================

    // INFO: test receiveParams executes successful proposal on dest chain
    function test_receiveParams_EmitsCorrectEvents() public {
        uint256 nonce = uint256(keccak256("test-cross-chain-proposalid"));
        uint256 index = 9;
        string memory setMessage = "Sensitive change";
        address targetAddr = address(mockC3GovernDApp);
        string[] memory targets = new string[](1);
        string[] memory toChainIds = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = targetAddr.toHexString();
        toChainIds[0] = getTestChainId(0);
        datas[0] = abi.encodeWithSelector(MockC3GovernDApp.mockC3ExecutableGov.selector, setMessage);
        vm.prank(address(c3caller));
        vm.expectEmit(true, true, true, true);
        emit IC3Governor.C3GovernorExec(nonce, index, targets[0], toChainIds[0], datas[0]);
        bytes memory result = c3governor.receiveParams(nonce, index, targets[0], toChainIds[0], datas[0]);
        assertEq(result, "");
        string memory _setMessage = mockC3GovernDApp.incomingMessage();
        assertEq(_setMessage, setMessage);
    }

    // INFO: test receiveParams where the call reverts
    function test_receiveParams_CallFails() public {
        uint256 nonce = uint256(keccak256("test-failed-cross-chain-proposal"));
        uint256 index = 1;
        string memory setMessage = "Sensitive change";
        address targetAddr = address(mockC3GovernDApp);
        string[] memory targets = new string[](1);
        string[] memory toChainIds = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = targetAddr.toHexString();
        toChainIds[0] = getTestChainId(0);
        datas[0] = abi.encodeWithSelector(mockC3GovernDApp.mockC3ExecutableRevertGov.selector, setMessage);
        bytes memory callFailedResult = abi.encodeWithSelector(MockC3GovernDApp.TargetCallFailed.selector);
        vm.prank(address(c3caller));
        vm.expectRevert(abi.encodeWithSelector(IC3Governor.C3Governor_ExecFailed.selector, callFailedResult));
        c3governor.receiveParams(nonce, index, targets[0], toChainIds[0], datas[0]);
    }

    // ============================
    // ======== C3FALLBACK ========
    // ============================

    // INFO: test fallback mechanism when cross-chain calls fail
    function test_C3Fallback_EmitsCorrectEvents() public {
        uint256 nonce = uint256(keccak256("cross-chain-tx"));
        uint256 index = 0;
        string memory target = address(mockC3GovernDApp).toHexString();
        string memory toChainId = getTestChainId(0);
        bytes memory data = abi.encodeWithSelector(MockC3GovernDApp.mockC3ExecutableGov.selector, "Sensitive change");

        bytes memory destChainData =
            abi.encodeWithSelector(C3Governor.receiveParams.selector, nonce, index, target, toChainId, data);

        bytes memory revertData =
            abi.encodeWithSelector(IC3Governor.C3Governor_ExecFailed.selector, "Target contract revert data");
        bytes memory reason = bytes("Target contract revert data");

        // NOTE: only C3Caller is able to call c3Fallback on C3CallerDApp
        vm.prank(address(c3caller));
        vm.expectEmit(true, false, false, true);
        emit IC3Governor.C3GovernorFallback(nonce, 0, target, toChainId, data, reason);
        c3governor.c3Fallback(c3governorDAppID, destChainData, revertData);

        (string memory failedTarget, string memory failedToChainId, bytes memory failedData) =
            c3governor.failed(nonce, 0);
        assertEq(failedTarget, target);
        assertEq(failedToChainId, toChainId);
        assertEq(failedData, data);
    }

    // INFO: test fallback with any selector other than receiveParams
    function test_C3Fallback_WrongSelector() public {
        uint256 nonce = uint256(keccak256("wrong-selector-call"));
        uint256 index = 47;
        vm.prank(address(c3caller));
        bytes memory wrongSelectorData = abi.encodeWithSelector(IC3Governor.doGov.selector, nonce, index);
        bool result = c3governor.c3Fallback(c3governorDAppID, wrongSelectorData, "");
        assertFalse(result);
    }

    // ===================================
    // ======== APPLY SELF AS GOV ========
    // ===================================

    function test_ApplySelfAsGov_Success() public {
        vm.startPrank(gov);
        MockC3GovClient mockC3GovClient = new MockC3GovClient(address(c3caller), gov);
        mockC3GovClient.changeGov(address(c3governor));
        vm.stopPrank();
        c3governor.applySelfAsGov(address(mockC3GovClient));
    }
}
