// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";

import {Helpers} from "../helpers/Helpers.sol";
import {MockC3GovernDApp} from "../helpers/mocks/MockC3GovernDApp.sol";
import {IC3GovernDApp} from "../../src/gov/IC3GovernDApp.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";
import {C3Caller} from "../../src/C3Caller.sol";
import {IC3Caller} from "../../src/IC3Caller.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";

contract C3GovernDAppTest is Helpers {
    C3UUIDKeeper c3UUIDKeeper;
    C3Caller c3caller;
    MockC3GovernDApp public governDApp;
    uint256 public testDAppID = 123;

    function setUp() public override {
        super.setUp();

        vm.startPrank(gov);
        c3UUIDKeeper = new C3UUIDKeeper();
        c3caller = new C3Caller(address(c3UUIDKeeper));

        // Add operator permissions
        c3UUIDKeeper.addOperator(address(c3caller));
        c3caller.addOperator(gov);
        c3caller.addOperator(mpc1);

        // Deploy govern dapp with initial txSender
        governDApp = new MockC3GovernDApp(gov, address(c3caller), user1, testDAppID);
        vm.stopPrank();
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public {
        assertEq(governDApp.gov(), gov);
        assertEq(governDApp.delay(), 2 days);
        assertTrue(governDApp.txSenders(user1));
        assertFalse(governDApp.txSenders(user2));
        assertEq(governDApp.dappID(), testDAppID);
        assertEq(governDApp.c3CallerProxy(), address(c3caller));
    }

    function test_Constructor_ZeroAddress() public {
        // This should work since constructor doesn't validate addresses
        MockC3GovernDApp dapp = new MockC3GovernDApp(
            address(0),
            address(c3caller),
            address(0),
            testDAppID
        );
        assertEq(dapp.gov(), address(0));
        assertTrue(dapp.txSenders(address(0)));
    }

    // ============ GOVERNANCE TESTS ============

    function test_ChangeGov_Success() public {
        vm.prank(gov);
        governDApp.changeGov(user1);
        
        // Should still return old gov until delay passes
        assertEq(governDApp.gov(), gov);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), user1);
    }

    function test_ChangeGov_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDApp.changeGov(user2);
    }

    function test_ChangeGov_C3Caller() public {
        // C3Caller should be able to change gov
        vm.prank(address(c3caller));
        governDApp.changeGov(user1);
        
        // Should still return old gov until delay passes
        assertEq(governDApp.gov(), gov);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), user1);
    }

    function test_ChangeGov_ZeroAddress() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_IsZeroAddress.selector,
                C3ErrorParam.Gov
            )
        );
        governDApp.changeGov(address(0));
    }

    function test_ChangeGov_EffectiveTime() public {
        vm.prank(gov);
        governDApp.changeGov(user1);
        
        uint256 effectiveTime = block.timestamp + 2 days;
        
        // Before effective time
        vm.warp(effectiveTime - 1);
        assertEq(governDApp.gov(), gov);
        
        // At effective time
        vm.warp(effectiveTime);
        assertEq(governDApp.gov(), user1);
        
        // After effective time
        vm.warp(effectiveTime + 1);
        assertEq(governDApp.gov(), user1);
    }

    function test_ChangeGov_MultipleChanges() public {
        vm.prank(gov);
        governDApp.changeGov(user1);
        
        // Fast forward past first delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), user1);
        
        // Now user1 can change gov
        vm.prank(user1);
        governDApp.changeGov(user2);
        
        // Should still return user1 until second delay passes
        assertEq(governDApp.gov(), user1);
        
        // Fast forward past second delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), user2);
    }

    // ============ DELAY TESTS ============

    function test_SetDelay_Success() public {
        vm.prank(gov);
        governDApp.setDelay(1 days);
        
        assertEq(governDApp.delay(), 1 days);
    }

    function test_SetDelay_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDApp.setDelay(1 days);
    }

    function test_SetDelay_C3Caller() public {
        vm.prank(address(c3caller));
        governDApp.setDelay(1 days);
        
        assertEq(governDApp.delay(), 1 days);
    }

    function test_SetDelay_ZeroDelay() public {
        vm.prank(gov);
        governDApp.setDelay(0);
        
        assertEq(governDApp.delay(), 0);
    }

    function test_SetDelay_LargeDelay() public {
        vm.prank(gov);
        governDApp.setDelay(365 days);
        
        assertEq(governDApp.delay(), 365 days);
    }

    function test_ChangeGov_WithCustomDelay() public {
        vm.prank(gov);
        governDApp.setDelay(1 days);
        
        vm.prank(gov);
        governDApp.changeGov(user1);
        
        // Should still return old gov until custom delay passes
        assertEq(governDApp.gov(), gov);
        
        // Fast forward past custom delay
        vm.warp(block.timestamp + 1 days + 1);
        assertEq(governDApp.gov(), user1);
    }

    // ============ TX SENDER TESTS ============

    function test_AddTxSender_Success() public {
        vm.prank(gov);
        governDApp.addTxSender(user2);
        
        assertTrue(governDApp.txSenders(user2));
    }

    function test_AddTxSender_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDApp.addTxSender(user2);
    }

    function test_AddTxSender_C3Caller() public {
        vm.prank(address(c3caller));
        governDApp.addTxSender(user2);
        
        assertTrue(governDApp.txSenders(user2));
    }

    function test_AddTxSender_AlreadyAdded() public {
        vm.prank(gov);
        governDApp.addTxSender(user2);
        
        vm.prank(gov);
        governDApp.addTxSender(user2);
        
        assertTrue(governDApp.txSenders(user2));
    }

    function test_DisableTxSender_Success() public {
        vm.prank(gov);
        governDApp.disableTxSender(user1);
        
        assertFalse(governDApp.txSenders(user1));
    }

    function test_DisableTxSender_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDApp.disableTxSender(user1);
    }

    function test_DisableTxSender_C3Caller() public {
        vm.prank(address(c3caller));
        governDApp.disableTxSender(user1);
        
        assertFalse(governDApp.txSenders(user1));
    }

    function test_DisableTxSender_AlreadyDisabled() public {
        vm.prank(gov);
        governDApp.disableTxSender(user1);
        
        vm.prank(gov);
        governDApp.disableTxSender(user1);
        
        assertFalse(governDApp.txSenders(user1));
    }

    function test_TxSenders_Multiple() public {
        vm.prank(gov);
        governDApp.addTxSender(user2);
        vm.prank(gov);
        governDApp.addTxSender(mpc1);
        
        assertTrue(governDApp.txSenders(user1));
        assertTrue(governDApp.txSenders(user2));
        assertTrue(governDApp.txSenders(mpc1));
        assertFalse(governDApp.txSenders(mpc2));
    }

    // ============ DOGOV TESTS ============

    function test_DoGov_Success() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(gov);
        governDApp.doGov(to, toChainID, data);
        
        // Should not revert
    }

    function test_DoGov_OnlyGov() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDApp.doGov(to, toChainID, data);
    }

    function test_DoGov_C3Caller() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(address(c3caller));
        governDApp.doGov(to, toChainID, data);
        
        // Should not revert
    }

    // ============ DOGOVBROADCAST TESTS ============

    function test_DoGovBroadcast_Success() public {
        string[] memory targets = new string[](2);
        targets[0] = "0x1234567890123456789012345678901234567890";
        targets[1] = "0x0987654321098765432109876543210987654321";
        
        string[] memory toChainIDs = new string[](2);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(gov);
        governDApp.doGovBroadcast(targets, toChainIDs, data);
        
        // Should not revert
    }

    function test_DoGovBroadcast_OnlyGov() public {
        string[] memory targets = new string[](1);
        targets[0] = "0x1234567890123456789012345678901234567890";
        
        string[] memory toChainIDs = new string[](1);
        toChainIDs[0] = "ethereum";
        
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDApp.doGovBroadcast(targets, toChainIDs, data);
    }

    function test_DoGovBroadcast_C3Caller() public {
        string[] memory targets = new string[](1);
        targets[0] = "0x1234567890123456789012345678901234567890";
        
        string[] memory toChainIDs = new string[](1);
        toChainIDs[0] = "ethereum";
        
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(address(c3caller));
        governDApp.doGovBroadcast(targets, toChainIDs, data);
        
        // Should not revert
    }

    function test_DoGovBroadcast_LengthMismatch() public {
        string[] memory targets = new string[](2);
        targets[0] = "0x1234567890123456789012345678901234567890";
        targets[1] = "0x0987654321098765432109876543210987654321";
        
        string[] memory toChainIDs = new string[](1);
        toChainIDs[0] = "ethereum";
        
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_LengthMismatch.selector,
                C3ErrorParam.Target,
                C3ErrorParam.ChainID
            )
        );
        governDApp.doGovBroadcast(targets, toChainIDs, data);
    }

    function test_DoGovBroadcast_EmptyArrays() public {
        string[] memory targets = new string[](0);
        string[] memory toChainIDs = new string[](0);
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.To));
        governDApp.doGovBroadcast(targets, toChainIDs, data);
    }

    // ============ ISVALID SENDER TESTS ============

    function test_IsValidSender_InitialTxSender() public {
        assertTrue(governDApp.isValidSender(user1));
    }

    function test_IsValidSender_AddedTxSender() public {
        vm.prank(gov);
        governDApp.addTxSender(user2);
        
        assertTrue(governDApp.isValidSender(user2));
    }

    function test_IsValidSender_DisabledTxSender() public {
        vm.prank(gov);
        governDApp.disableTxSender(user1);
        
        assertFalse(governDApp.isValidSender(user1));
    }

    function test_IsValidSender_NonTxSender() public {
        assertFalse(governDApp.isValidSender(user2));
        assertFalse(governDApp.isValidSender(address(0)));
    }

    // ============ EDGE CASES ============

    function test_ChangeGov_SameAddress() public {
        vm.prank(gov);
        governDApp.changeGov(gov);
        
        // Should still return old gov until delay passes
        assertEq(governDApp.gov(), gov);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), gov);
    }

    function test_Gov_AfterGovernanceChange() public {
        vm.prank(gov);
        governDApp.changeGov(user1);
        
        // Change gov again before first change takes effect
        vm.prank(gov);
        governDApp.changeGov(user2);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        // The second change should take effect because it has a later effective time
        assertEq(governDApp.gov(), user2);
    }

    function test_TxSender_ZeroAddress() public {
        vm.prank(gov);
        governDApp.addTxSender(address(0));
        
        assertTrue(governDApp.txSenders(address(0)));
    }

    // ============ STRESS TESTS ============

    function test_MultipleTxSenders() public {
        address[] memory testSenders = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            testSenders[i] = address(uint160(i + 1000));
        }
        
        // Add all tx senders
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(gov);
            governDApp.addTxSender(testSenders[i]);
        }
        
        // Verify all are tx senders
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(governDApp.txSenders(testSenders[i]));
        }
        
        // Disable all tx senders
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(gov);
            governDApp.disableTxSender(testSenders[i]);
        }
        
        // Verify none are tx senders
        for (uint256 i = 0; i < 10; i++) {
            assertFalse(governDApp.txSenders(testSenders[i]));
        }
    }

    function test_MultipleGovernanceChanges() public {
        address[] memory newGovs = new address[](5);
        newGovs[0] = user1;
        newGovs[1] = user2;
        newGovs[2] = mpc1;
        newGovs[3] = mpc2;
        newGovs[4] = admin;
        
        // Make multiple governance changes with proper timing
        vm.prank(gov);
        governDApp.changeGov(newGovs[0]);
        
        // Fast forward past first delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), newGovs[0]);
        
        vm.prank(newGovs[0]);
        governDApp.changeGov(newGovs[1]);
        
        // Fast forward past second delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), newGovs[1]);
        
        vm.prank(newGovs[1]);
        governDApp.changeGov(newGovs[2]);
        
        // Fast forward past third delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), newGovs[2]);
        
        vm.prank(newGovs[2]);
        governDApp.changeGov(newGovs[3]);
        
        // Fast forward past fourth delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), newGovs[3]);
        
        vm.prank(newGovs[3]);
        governDApp.changeGov(newGovs[4]);
        
        // Fast forward past fifth delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDApp.gov(), newGovs[4]);
    }

    function test_DoGovBroadcast_LargeArrays() public {
        string[] memory targets = new string[](100);
        string[] memory toChainIDs = new string[](100);
        
        for (uint256 i = 0; i < 100; i++) {
            targets[i] = string(abi.encodePacked("0x", vm.toString(i)));
            toChainIDs[i] = string(abi.encodePacked("chain_", vm.toString(i)));
        }
        
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(gov);
        governDApp.doGovBroadcast(targets, toChainIDs, data);
        
        // Should not revert
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function test_Gas_ChangeGov() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDApp.changeGov(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for changeGov:", gasUsed);
    }

    function test_Gas_SetDelay() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDApp.setDelay(1 days);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for setDelay:", gasUsed);
    }

    function test_Gas_AddTxSender() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDApp.addTxSender(user2);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for addTxSender:", gasUsed);
    }

    function test_Gas_DisableTxSender() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDApp.disableTxSender(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for disableTxSender:", gasUsed);
    }

    function test_Gas_DoGov() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDApp.doGov(to, toChainID, data);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for doGov:", gasUsed);
    }

    function test_Gas_DoGovBroadcast() public {
        string[] memory targets = new string[](2);
        targets[0] = "0x1234567890123456789012345678901234567890";
        targets[1] = "0x0987654321098765432109876543210987654321";
        
        string[] memory toChainIDs = new string[](2);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        
        bytes memory data = abi.encodeWithSignature("test()");
        
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDApp.doGovBroadcast(targets, toChainIDs, data);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for doGovBroadcast:", gasUsed);
    }

    function test_Gas_Gov() public {
        uint256 gasBefore = gasleft();
        governDApp.gov();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for gov:", gasUsed);
    }

    function test_Gas_TxSenders() public {
        uint256 gasBefore = gasleft();
        governDApp.txSenders(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for txSenders:", gasUsed);
    }
}
