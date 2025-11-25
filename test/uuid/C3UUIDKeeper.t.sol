// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Helpers} from "../helpers/Helpers.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {IC3UUIDKeeper} from "../../src/uuid/IC3UUIDKeeper.sol";
import {IC3GovClient} from "../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";

contract C3UUIDKeeperTest is Helpers {
    uint256 mockDAppID = uint256(keccak256("Mmock DApp ID"));

    function setUp() public override {
        super.setUp();
        _deployC3UUIDKeeper(gov);
        _deployC3DAppManager(gov);
        _deployC3Caller(gov);
        _setC3Caller(gov);
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        uuidKeeper = new C3UUIDKeeper();
    }

    function test_State() public view {
        uint256 _currentNonce = uuidKeeper.currentNonce();
        assertEq(_currentNonce, 0);
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_RevertWhen_CallerNotGov() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        uuidKeeper.revokeSwapIn(keccak256("completed swap ID"), mockDAppID);
    }

    function test_RevertWhen_CallerNotC3Caller() public {
        bytes memory onlyAuthC3CallerError = abi.encodeWithSelector(
            IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller
        );

        vm.expectRevert(onlyAuthC3CallerError);
        uuidKeeper.genUUID(
            mockDAppID, "to address", "to chain ID", abi.encodeWithSelector(C3UUIDKeeper.genUUID.selector)
        );

        vm.expectRevert(onlyAuthC3CallerError);
        uuidKeeper.registerUUID(keccak256("sample UUID"), mockDAppID);
    }

    // ==========================
    // ======== GEN UUID ========
    // ==========================

    function test_GenUUID_Success() public {
        uint256 nonceBefore = uuidKeeper.currentNonce();
        string memory mockTarget = "to address";
        string memory mockToChainID = "to chain ID";
        bytes memory data = abi.encodeWithSelector(C3UUIDKeeper.genUUID.selector);
        bytes32 expectedUUID = keccak256(
            abi.encode(
                address(uuidKeeper),
                address(c3caller),
                block.chainid,
                mockDAppID,
                mockTarget,
                mockToChainID,
                nonceBefore + 1,
                data
            )
        );
        vm.prank(address(c3caller));
        vm.expectEmit(true, true, true, true);
        emit IC3UUIDKeeper.UUIDGenerated(
            expectedUUID, mockDAppID, address(c3caller), mockTarget, mockToChainID, nonceBefore + 1, data
        );
        bytes32 uuid = uuidKeeper.genUUID(mockDAppID, mockTarget, mockToChainID, data);
        assertEq(uuidKeeper.currentNonce(), nonceBefore + 1);
        assertEq(uuid, expectedUUID);
        assertTrue(uuidKeeper.doesUUIDExist(uuid));
    }

    // ===============================
    // ======== REGISTER UUID ========
    // ===============================

    function test_RegisterUUID_Success() public {
        bytes32 uuid = keccak256("sample UUID");
        vm.prank(address(c3caller));
        vm.expectEmit(true, true, true, true);
        emit IC3UUIDKeeper.UUIDCompleted(uuid, mockDAppID, address(c3caller));
        uuidKeeper.registerUUID(uuid, mockDAppID);
        assertTrue(uuidKeeper.completedSwapIn(uuid));
        assertTrue(uuidKeeper.isCompleted(uuid));
    }

    function test_RegisterUUID_RevertWhen_UUIDIsAlreadyCompleted() public {
        bytes32 uuid = keccak256("sample UUID");
        vm.startPrank(address(c3caller));
        uuidKeeper.registerUUID(uuid, mockDAppID);
        vm.expectRevert(abi.encodeWithSelector(IC3UUIDKeeper.C3UUIDKeeper_UUIDAlreadyCompleted.selector, uuid));
        uuidKeeper.registerUUID(uuid, mockDAppID);
        vm.stopPrank();
    }

    // ================================
    // ======== REVOKE SWAP IN ========
    // ================================

    function test_RevokeSwapIn_Success() public {
        bytes32 uuid = keccak256("sample UUID");
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3UUIDKeeper.UUIDRevoked(uuid, mockDAppID, address(gov));
        uuidKeeper.revokeSwapIn(uuid, mockDAppID);
        assertFalse(uuidKeeper.completedSwapIn(uuid));
        assertFalse(uuidKeeper.isCompleted(uuid));
    }

    // ==================================
    // ======== CALC CALLER UUID ========
    // ==================================

    function test_CalcCallerUUID_Success() public {
        string memory target = "to address";
        string memory toChainID = "to chain ID";
        bytes memory data = abi.encode("some executable data");
        bytes32 expectedUUID = uuidKeeper.calcCallerUUID(address(c3caller), mockDAppID, target, toChainID, data);
        vm.prank(address(c3caller));
        bytes32 actualUUID = uuidKeeper.genUUID(mockDAppID, target, toChainID, data);
        assertEq(actualUUID, expectedUUID);
    }

    // =============================================
    // ======== CALC CALLER UUID WITH NONCE ========
    // =============================================

    function test_CalcCallerUUIDWithNonce_Success() public {
        string memory target = "to address";
        string memory toChainID = "to chain ID";
        bytes memory data = abi.encode("some executable data");
        uint256 currentNonce = uuidKeeper.currentNonce();
        bytes32 expectedUUID = uuidKeeper.calcCallerUUIDWithNonce(
            address(c3caller), mockDAppID, target, toChainID, data, currentNonce + 1
        );
        vm.prank(address(c3caller));
        bytes32 actualUUID = uuidKeeper.genUUID(mockDAppID, target, toChainID, data);
        assertEq(actualUUID, expectedUUID);
    }

    // ======================================================
    // ======== CALC CALLER UUID ENCODING WITH NONCE ========
    // ======================================================

    function test_CalcCallerUUIDEncodingWithNonce_Success() public {
        string memory target = "to address";
        string memory toChainID = "to chain ID";
        bytes memory data = abi.encode("some executable data");
        uint256 currentNonce = uuidKeeper.currentNonce();
        bytes memory expectedEncoding = uuidKeeper.calcCallerUUIDEncodingWithNonce(
            address(c3caller), mockDAppID, target, toChainID, data, currentNonce + 1
        );
        vm.prank(address(c3caller));
        bytes32 actualUUID = uuidKeeper.genUUID(mockDAppID, target, toChainID, data);
        assertEq(actualUUID, keccak256(expectedEncoding));
    }
}
