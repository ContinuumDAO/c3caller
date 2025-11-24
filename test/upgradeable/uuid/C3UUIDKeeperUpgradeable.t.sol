// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Helpers} from "../../helpers/Helpers.sol";
import {C3UUIDKeeperUpgradeable} from "../../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {IC3UUIDKeeper} from "../../../src/uuid/IC3UUIDKeeper.sol";
import {IC3GovClient} from "../../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../../src/utils/C3CallerUtils.sol";
import {C3DAppManagerUpgradeable} from "../../../src/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {C3CallerUpgradeable} from "../../../src/upgradeable/C3CallerUpgradeable.sol";

contract C3UUIDKeeperUpgradeableTest is Helpers {
    uint256 mockDAppID = uint256(keccak256("Mock DApp ID"));

    function setUp() public override {
        super.setUp();
        _deployC3UUIDKeeperUpgradeable(gov);
        _deployC3DAppManagerUpgradeable(gov);
        _deployC3CallerUpgradeable(gov);
        _setC3CallerUpgradeable(gov);
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        _deployC3UUIDKeeperUpgradeable(gov);
    }

    function test_State() public view {
        uint256 _currentNonce = uuidKeeper_u.currentNonce();
        assertEq(_currentNonce, 0);
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_RevertWhen_CallerNotGov() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        uuidKeeper_u.revokeSwapIn(keccak256("completed swap ID"), mockDAppID);
    }

    function test_RevertWhen_CallerNotC3Caller() public {
        bytes memory onlyAuthC3CallerError = abi.encodeWithSelector(
            IC3GovClient.C3GovClient_OnlyAuthorized.selector,
            C3ErrorParam.Sender,
            C3ErrorParam.C3Caller
        );

        vm.expectRevert(onlyAuthC3CallerError);
        uuidKeeper_u.genUUID(mockDAppID, "to address", "to chain ID", abi.encodeWithSelector(C3UUIDKeeperUpgradeable.genUUID.selector));

        vm.expectRevert(onlyAuthC3CallerError);
        uuidKeeper_u.registerUUID(keccak256("sample UUID"), mockDAppID);
    }

    // ==========================
    // ======== GEN UUID ========
    // ==========================

    function test_GenUUID_Success() public {
        uint256 nonceBefore = uuidKeeper_u.currentNonce();
        string memory mockTarget = "to address";
        string memory mockToChainID = "to chain ID";
        bytes memory data = abi.encodeWithSelector(C3UUIDKeeperUpgradeable.genUUID.selector);
        bytes32 expectedUUID = keccak256(
            abi.encode(address(uuidKeeper_u), address(c3caller_u), block.chainid, mockDAppID, mockTarget, mockToChainID, nonceBefore + 1, data)
        );
        vm.prank(address(c3caller_u));
        vm.expectEmit(true, true, true, true);
        emit IC3UUIDKeeper.UUIDGenerated(expectedUUID, mockDAppID, address(c3caller_u), mockTarget, mockToChainID, nonceBefore + 1, data);
        bytes32 uuid = uuidKeeper_u.genUUID(mockDAppID, mockTarget, mockToChainID, data);
        assertEq(uuidKeeper_u.currentNonce(), nonceBefore + 1);
        assertEq(uuid, expectedUUID);
        assertTrue(uuidKeeper_u.doesUUIDExist(uuid));
    }

    // ===============================
    // ======== REGISTER UUID ========
    // ===============================

    function test_RegisterUUID_Success() public {
        bytes32 uuid = keccak256("sample UUID");
        vm.prank(address(c3caller_u));
        vm.expectEmit(true, true, true, true);
        emit IC3UUIDKeeper.UUIDCompleted(uuid, mockDAppID, address(c3caller_u));
        uuidKeeper_u.registerUUID(uuid, mockDAppID);
        assertTrue(uuidKeeper_u.completedSwapIn(uuid));
        assertTrue(uuidKeeper_u.isCompleted(uuid));
    }

    function test_RegisterUUID_RevertWhen_UUIDIsAlreadyCompleted() public {
        bytes32 uuid = keccak256("sample UUID");
        vm.startPrank(address(c3caller_u));
        uuidKeeper_u.registerUUID(uuid, mockDAppID);
        vm.expectRevert(abi.encodeWithSelector(IC3UUIDKeeper.C3UUIDKeeper_UUIDAlreadyCompleted.selector, uuid));
        uuidKeeper_u.registerUUID(uuid, mockDAppID);
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
        uuidKeeper_u.revokeSwapIn(uuid, mockDAppID);
        assertFalse(uuidKeeper_u.completedSwapIn(uuid));
        assertFalse(uuidKeeper_u.isCompleted(uuid));
    }

    // ==================================
    // ======== CALC CALLER UUID ========
    // ==================================

    function test_CalcCallerUUID_Success() public {
        string memory target = "to address";
        string memory toChainID = "to chain ID";
        bytes memory data = abi.encode("some executable data");
        bytes32 expectedUUID = uuidKeeper_u.calcCallerUUID(address(c3caller_u), mockDAppID, target, toChainID, data);
        vm.prank(address(c3caller_u));
        bytes32 actualUUID = uuidKeeper_u.genUUID(mockDAppID, target, toChainID, data);
        assertEq(actualUUID, expectedUUID);
    }

    // =============================================
    // ======== CALC CALLER UUID WITH NONCE ========
    // =============================================

    function test_CalcCallerUUIDWithNonce_Success() public {
        string memory target = "to address";
        string memory toChainID = "to chain ID";
        bytes memory data = abi.encode("some executable data");
        uint256 currentNonce = uuidKeeper_u.currentNonce();
        bytes32 expectedUUID = uuidKeeper_u.calcCallerUUIDWithNonce(address(c3caller_u), mockDAppID, target, toChainID, data, currentNonce + 1);
        vm.prank(address(c3caller_u));
        bytes32 actualUUID = uuidKeeper_u.genUUID(mockDAppID, target, toChainID, data);
        assertEq(actualUUID, expectedUUID);
    }

    // ======================================================
    // ======== CALC CALLER UUID ENCODING WITH NONCE ========
    // ======================================================

    function test_CalcCallerUUIDEncodingWithNonce_Success() public {
        string memory target = "to address";
        string memory toChainID = "to chain ID";
        bytes memory data = abi.encode("some executable data");
        uint256 currentNonce = uuidKeeper_u.currentNonce();
        bytes memory expectedEncoding = uuidKeeper_u.calcCallerUUIDEncodingWithNonce(address(c3caller_u), mockDAppID, target, toChainID, data, currentNonce + 1);
        vm.prank(address(c3caller_u));
        bytes32 actualUUID = uuidKeeper_u.genUUID(mockDAppID, target, toChainID, data);
        assertEq(actualUUID, keccak256(expectedEncoding));
    }
}
