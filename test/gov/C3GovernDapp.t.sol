// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";

import {Helpers} from "../helpers/Helpers.sol";
import {MockC3GovernDapp} from "../helpers/mocks/MockC3GovernDapp.sol";
import {IC3GovernDapp} from "../../src/gov/IC3GovernDapp.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";
import {C3Caller} from "../../src/C3Caller.sol";
import {IC3Caller} from "../../src/IC3Caller.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";

contract C3GovernDappTest is Helpers {
    C3UUIDKeeper c3UUIDKeeper;
    C3Caller c3caller;
    MockC3GovernDapp public governDapp;
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

        // Deploy govern dapp with initial txSender
        governDapp = new MockC3GovernDapp(gov, address(c3caller), user1, testDappID);
        vm.stopPrank();
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public {
        assertEq(governDapp.gov(), gov);
        assertEq(governDapp.delay(), 2 days);
        assertTrue(governDapp.txSenders(user1));
        assertFalse(governDapp.txSenders(user2));
        assertEq(governDapp.dappID(), testDappID);
        assertEq(governDapp.c3CallerProxy(), address(c3caller));
    }

    function test_Constructor_ZeroAddress() public {
        // This should work since constructor doesn't validate addresses
        MockC3GovernDapp dapp = new MockC3GovernDapp(
            address(0),
            address(c3caller),
            address(0),
            testDappID
        );
        assertEq(dapp.gov(), address(0));
        assertTrue(dapp.txSenders(address(0)));
    }

    // ============ GOVERNANCE TESTS ============

    function test_ChangeGov_Success() public {
        vm.prank(gov);
        governDapp.changeGov(user1);
        
        // Should still return old gov until delay passes
        assertEq(governDapp.gov(), gov);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), user1);
    }

    function test_ChangeGov_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDapp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDapp.changeGov(user2);
    }

    function test_ChangeGov_C3Caller() public {
        // C3Caller should be able to change gov
        vm.prank(address(c3caller));
        governDapp.changeGov(user1);
        
        // Should still return old gov until delay passes
        assertEq(governDapp.gov(), gov);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), user1);
    }

    function test_ChangeGov_ZeroAddress() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDapp.C3GovernDApp_IsZeroAddress.selector,
                C3ErrorParam.Gov
            )
        );
        governDapp.changeGov(address(0));
    }

    function test_ChangeGov_EffectiveTime() public {
        vm.prank(gov);
        governDapp.changeGov(user1);
        
        uint256 effectiveTime = block.timestamp + 2 days;
        
        // Before effective time
        vm.warp(effectiveTime - 1);
        assertEq(governDapp.gov(), gov);
        
        // At effective time
        vm.warp(effectiveTime);
        assertEq(governDapp.gov(), user1);
        
        // After effective time
        vm.warp(effectiveTime + 1);
        assertEq(governDapp.gov(), user1);
    }

    function test_ChangeGov_MultipleChanges() public {
        vm.prank(gov);
        governDapp.changeGov(user1);
        
        // Fast forward past first delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), user1);
        
        // Now user1 can change gov
        vm.prank(user1);
        governDapp.changeGov(user2);
        
        // Should still return user1 until second delay passes
        assertEq(governDapp.gov(), user1);
        
        // Fast forward past second delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), user2);
    }

    // ============ DELAY TESTS ============

    function test_SetDelay_Success() public {
        vm.prank(gov);
        governDapp.setDelay(1 days);
        
        assertEq(governDapp.delay(), 1 days);
    }

    function test_SetDelay_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDapp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDapp.setDelay(1 days);
    }

    function test_SetDelay_C3Caller() public {
        vm.prank(address(c3caller));
        governDapp.setDelay(1 days);
        
        assertEq(governDapp.delay(), 1 days);
    }

    function test_SetDelay_ZeroDelay() public {
        vm.prank(gov);
        governDapp.setDelay(0);
        
        assertEq(governDapp.delay(), 0);
    }

    function test_SetDelay_LargeDelay() public {
        vm.prank(gov);
        governDapp.setDelay(365 days);
        
        assertEq(governDapp.delay(), 365 days);
    }

    function test_ChangeGov_WithCustomDelay() public {
        vm.prank(gov);
        governDapp.setDelay(1 days);
        
        vm.prank(gov);
        governDapp.changeGov(user1);
        
        // Should still return old gov until custom delay passes
        assertEq(governDapp.gov(), gov);
        
        // Fast forward past custom delay
        vm.warp(block.timestamp + 1 days + 1);
        assertEq(governDapp.gov(), user1);
    }

    // ============ TX SENDER TESTS ============

    function test_AddTxSender_Success() public {
        vm.prank(gov);
        governDapp.addTxSender(user2);
        
        assertTrue(governDapp.txSenders(user2));
    }

    function test_AddTxSender_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDapp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDapp.addTxSender(user2);
    }

    function test_AddTxSender_C3Caller() public {
        vm.prank(address(c3caller));
        governDapp.addTxSender(user2);
        
        assertTrue(governDapp.txSenders(user2));
    }

    function test_AddTxSender_AlreadyAdded() public {
        vm.prank(gov);
        governDapp.addTxSender(user2);
        
        vm.prank(gov);
        governDapp.addTxSender(user2);
        
        assertTrue(governDapp.txSenders(user2));
    }

    function test_DisableTxSender_Success() public {
        vm.prank(gov);
        governDapp.disableTxSender(user1);
        
        assertFalse(governDapp.txSenders(user1));
    }

    function test_DisableTxSender_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDapp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDapp.disableTxSender(user1);
    }

    function test_DisableTxSender_C3Caller() public {
        vm.prank(address(c3caller));
        governDapp.disableTxSender(user1);
        
        assertFalse(governDapp.txSenders(user1));
    }

    function test_DisableTxSender_AlreadyDisabled() public {
        vm.prank(gov);
        governDapp.disableTxSender(user1);
        
        vm.prank(gov);
        governDapp.disableTxSender(user1);
        
        assertFalse(governDapp.txSenders(user1));
    }

    function test_TxSenders_Multiple() public {
        vm.prank(gov);
        governDapp.addTxSender(user2);
        vm.prank(gov);
        governDapp.addTxSender(mpc1);
        
        assertTrue(governDapp.txSenders(user1));
        assertTrue(governDapp.txSenders(user2));
        assertTrue(governDapp.txSenders(mpc1));
        assertFalse(governDapp.txSenders(mpc2));
    }

    // ============ DOGOV TESTS ============

    function test_DoGov_Success() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(gov);
        governDapp.doGov(to, toChainID, data);
        
        // Should not revert
    }

    function test_DoGov_OnlyGov() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDapp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDapp.doGov(to, toChainID, data);
    }

    function test_DoGov_C3Caller() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(address(c3caller));
        governDapp.doGov(to, toChainID, data);
        
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
        governDapp.doGovBroadcast(targets, toChainIDs, data);
        
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
                IC3GovernDapp.C3GovernDApp_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrC3Caller
            )
        );
        governDapp.doGovBroadcast(targets, toChainIDs, data);
    }

    function test_DoGovBroadcast_C3Caller() public {
        string[] memory targets = new string[](1);
        targets[0] = "0x1234567890123456789012345678901234567890";
        
        string[] memory toChainIDs = new string[](1);
        toChainIDs[0] = "ethereum";
        
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(address(c3caller));
        governDapp.doGovBroadcast(targets, toChainIDs, data);
        
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
                IC3GovernDapp.C3GovernDApp_LengthMismatch.selector,
                C3ErrorParam.Target,
                C3ErrorParam.ChainID
            )
        );
        governDapp.doGovBroadcast(targets, toChainIDs, data);
    }

    function test_DoGovBroadcast_EmptyArrays() public {
        string[] memory targets = new string[](0);
        string[] memory toChainIDs = new string[](0);
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.To));
        governDapp.doGovBroadcast(targets, toChainIDs, data);
    }

    // ============ ISVALID SENDER TESTS ============

    function test_IsValidSender_InitialTxSender() public {
        assertTrue(governDapp.isValidSender(user1));
    }

    function test_IsValidSender_AddedTxSender() public {
        vm.prank(gov);
        governDapp.addTxSender(user2);
        
        assertTrue(governDapp.isValidSender(user2));
    }

    function test_IsValidSender_DisabledTxSender() public {
        vm.prank(gov);
        governDapp.disableTxSender(user1);
        
        assertFalse(governDapp.isValidSender(user1));
    }

    function test_IsValidSender_NonTxSender() public {
        assertFalse(governDapp.isValidSender(user2));
        assertFalse(governDapp.isValidSender(address(0)));
    }

    // ============ EDGE CASES ============

    function test_ChangeGov_SameAddress() public {
        vm.prank(gov);
        governDapp.changeGov(gov);
        
        // Should still return old gov until delay passes
        assertEq(governDapp.gov(), gov);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), gov);
    }

    function test_Gov_AfterGovernanceChange() public {
        vm.prank(gov);
        governDapp.changeGov(user1);
        
        // Change gov again before first change takes effect
        vm.prank(gov);
        governDapp.changeGov(user2);
        
        // Fast forward past delay
        vm.warp(block.timestamp + 2 days + 1);
        // The second change should take effect because it has a later effective time
        assertEq(governDapp.gov(), user2);
    }

    function test_TxSender_ZeroAddress() public {
        vm.prank(gov);
        governDapp.addTxSender(address(0));
        
        assertTrue(governDapp.txSenders(address(0)));
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
            governDapp.addTxSender(testSenders[i]);
        }
        
        // Verify all are tx senders
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(governDapp.txSenders(testSenders[i]));
        }
        
        // Disable all tx senders
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(gov);
            governDapp.disableTxSender(testSenders[i]);
        }
        
        // Verify none are tx senders
        for (uint256 i = 0; i < 10; i++) {
            assertFalse(governDapp.txSenders(testSenders[i]));
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
        governDapp.changeGov(newGovs[0]);
        
        // Fast forward past first delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), newGovs[0]);
        
        vm.prank(newGovs[0]);
        governDapp.changeGov(newGovs[1]);
        
        // Fast forward past second delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), newGovs[1]);
        
        vm.prank(newGovs[1]);
        governDapp.changeGov(newGovs[2]);
        
        // Fast forward past third delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), newGovs[2]);
        
        vm.prank(newGovs[2]);
        governDapp.changeGov(newGovs[3]);
        
        // Fast forward past fourth delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), newGovs[3]);
        
        vm.prank(newGovs[3]);
        governDapp.changeGov(newGovs[4]);
        
        // Fast forward past fifth delay
        vm.warp(block.timestamp + 2 days + 1);
        assertEq(governDapp.gov(), newGovs[4]);
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
        governDapp.doGovBroadcast(targets, toChainIDs, data);
        
        // Should not revert
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function test_Gas_ChangeGov() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDapp.changeGov(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for changeGov:", gasUsed);
    }

    function test_Gas_SetDelay() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDapp.setDelay(1 days);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for setDelay:", gasUsed);
    }

    function test_Gas_AddTxSender() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDapp.addTxSender(user2);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for addTxSender:", gasUsed);
    }

    function test_Gas_DisableTxSender() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDapp.disableTxSender(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for disableTxSender:", gasUsed);
    }

    function test_Gas_DoGov() public {
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSignature("test()");
        
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        governDapp.doGov(to, toChainID, data);
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
        governDapp.doGovBroadcast(targets, toChainIDs, data);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for doGovBroadcast:", gasUsed);
    }

    function test_Gas_Gov() public {
        uint256 gasBefore = gasleft();
        governDapp.gov();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for gov:", gasUsed);
    }

    function test_Gas_TxSenders() public {
        uint256 gasBefore = gasleft();
        governDapp.txSenders(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for txSenders:", gasUsed);
    }
}
