// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Helpers} from "../helpers/Helpers.sol";
import {MockC3GovClient} from "../mocks/MockC3GovClient.sol";

import {C3GovClient} from "../../src/gov/C3GovClient.sol";
import {IC3GovClient} from "../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";

contract C3GovClientTest is Helpers {
    MockC3GovClient mockC3GovClient;

    function setUp() public virtual override {
        super.setUp();
        mockC3GovClient = new MockC3GovClient(address(c3caller), admin);
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        vm.expectEmit(true, true, true, true);
        emit IC3GovClient.ApplyGov(address(0), admin);
        mockC3GovClient = new MockC3GovClient(address(c3caller), admin);
    }

    function test_State() public view {
        address _c3caller = mockC3GovClient.c3caller();
        address _gov = mockC3GovClient.gov();
        address _pendingGov = mockC3GovClient.pendingGov();
        assertEq(_c3caller, address(0));
        assertEq(_gov, admin);
        assertEq(_pendingGov, address(0));
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_OnlyC3Caller() public {
        vm.prank(address(c3caller));
        mockC3GovClient.mockFunctionOnlyC3Caller("Caller is c3caller.");
        assertEq(mockC3GovClient.message(), "Caller is c3caller.");
    }

    function test_OnlyGov() public {
        vm.prank(admin);
        mockC3GovClient.mockFunctionOnlyGov("Caller is governance.");
        assertEq(mockC3GovClient.message(), "Caller is governance.");
    }

    function test_RevertWhen_CallerNotC3Caller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller
            )
        );
        mockC3GovClient.mockFunctionOnlyC3Caller("Caller not c3caller!");
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
        vm.prank(admin);
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
        vm.prank(admin);
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
        vm.prank(admin);
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
        vm.prank(admin);
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
        vm.prank(admin);
        mockC3GovClient.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        mockC3GovClient.mockFunctionWhenNotPaused("Contract is paused!");
    }

    // =========================
    // ======== UNPAUSE ========
    // =========================

    function test_Unpause_RevertWhen_CallerNotGov() public {
        vm.prank(admin);
        mockC3GovClient.pause();
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        mockC3GovClient.unpause();
    }
}
