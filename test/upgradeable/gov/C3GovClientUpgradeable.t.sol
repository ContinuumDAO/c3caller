// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Helpers} from "../../helpers/Helpers.sol";
import {MockC3GovClientUpgradeable} from "../../mocks/MockC3GovClientUpgradeable.sol";

import {C3GovClientUpgradeable} from "../../../src/upgradeable/gov/C3GovClientUpgradeable.sol";
import {IC3GovClient} from "../../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../../src/utils/C3CallerUtils.sol";
import {C3UUIDKeeperUpgradeable} from "../../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {C3DAppManagerUpgradeable} from "../../../src/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {C3CallerUpgradeable} from "../../../src/upgradeable/C3CallerUpgradeable.sol";
import {C3CallerProxy} from "../../../src/utils/C3CallerProxy.sol";

contract C3GovClientUpgradeableTest is Helpers {
    MockC3GovClientUpgradeable mockC3GovClient;

    function setUp() public virtual override {
        super.setUp();
        _deployC3UUIDKeeperUpgradeable(gov);
        _deployC3DAppManagerUpgradeable(gov);
        _deployC3CallerUpgradeable(gov);
        _setC3CallerUpgradeable(gov);
        mockC3GovClient = _deployC3GovClientUpgradeable(gov, gov);
        vm.prank(gov);
        mockC3GovClient.setC3Caller(address(c3caller_u));
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        vm.startPrank(gov);
        MockC3GovClientUpgradeable impl = new MockC3GovClientUpgradeable();
        bytes memory initData = abi.encodeWithSelector(MockC3GovClientUpgradeable.initialize.selector, gov);
        vm.expectEmit(true, true, true, true);
        emit IC3GovClient.ApplyGov(address(0), gov);
        C3CallerProxy proxy = new C3CallerProxy(address(impl), initData);
        vm.stopPrank();
    }

    function test_State() public view {
        address _c3caller = mockC3GovClient.c3caller();
        address _gov = mockC3GovClient.gov();
        address _pendingGov = mockC3GovClient.pendingGov();
        assertEq(_c3caller, address(c3caller_u));
        assertEq(_gov, gov);
        assertEq(_pendingGov, address(0));
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_OnlyC3Caller() public {
        vm.prank(address(c3caller_u));
        mockC3GovClient.mockFunctionOnlyC3Caller("Caller is c3caller_u.");
        assertEq(mockC3GovClient.message(), "Caller is c3caller_u.");
    }

    function test_OnlyGov() public {
        vm.prank(gov);
        mockC3GovClient.mockFunctionOnlyGov("Caller is governance.");
        assertEq(mockC3GovClient.message(), "Caller is governance.");
    }

    function test_RevertWhen_CallerNotC3Caller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller
            )
        );
        mockC3GovClient.mockFunctionOnlyC3Caller("Caller not c3caller_u!");
    }

    function test_RevertWhen_CallerNotGov() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        mockC3GovClient.mockFunctionOnlyGov("Caller not governance!");
    }

    // ==============================
    // ======== SET C3CALLER ========
    // ==============================

    function test_SetC3Caller_Success() public {
        address c3callerBefore = mockC3GovClient.c3caller();
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3GovClient.SetC3Caller(c3callerBefore, user1);
        mockC3GovClient.setC3Caller(user1);
        address c3callerAfter = mockC3GovClient.c3caller();
        assertEq(c3callerAfter, user1);
    }

    function test_SetC3Caller_RevertWhen_CallerNotGov() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        mockC3GovClient.setC3Caller(user1);
    }

    // ============================
    // ======== CHANGE GOV ========
    // ============================

    function test_ChangeGov_Success() public {
        address _gov = mockC3GovClient.gov();
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3GovClient.ChangeGov(_gov, user1);
        mockC3GovClient.changeGov(user1);
        assertEq(mockC3GovClient.pendingGov(), user1);
    }

    function test_ChangeGov_RevertWhen_NotGov() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        mockC3GovClient.changeGov(user1);
    }

    // ===========================
    // ======== APPLY GOV ========
    // ===========================

    function test_ApplyGov_Success() public {
        vm.prank(gov);
        mockC3GovClient.changeGov(user1);
        address _govBefore = mockC3GovClient.gov();
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3GovClient.ApplyGov(_govBefore, user1);
        mockC3GovClient.applyGov();
        address _govAfter = mockC3GovClient.gov();
        address _pendingGovAfter = mockC3GovClient.pendingGov();
        assertEq(_govAfter, user1);
        assertEq(_pendingGovAfter, address(0));
    }

    function test_ApplyGov_RevertWhen_CallerNotPendingGov() public {
        vm.prank(gov);
        mockC3GovClient.changeGov(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.PendingGov
            )
        );
        mockC3GovClient.applyGov();
    }

    // =======================
    // ======== PAUSE ========
    // =======================

    function test_Pause_RevertWhen_CallerNotGov() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        mockC3GovClient.pause();
    }

    function test_Pause_RevertWhen_Paused() public {
        vm.prank(gov);
        mockC3GovClient.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        mockC3GovClient.mockFunctionWhenNotPaused("Contract is paused!");
    }

    // =========================
    // ======== UNPAUSE ========
    // =========================

    function test_Unpause_RevertWhen_CallerNotGov() public {
        vm.prank(gov);
        mockC3GovClient.pause();
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        mockC3GovClient.unpause();
    }
}
