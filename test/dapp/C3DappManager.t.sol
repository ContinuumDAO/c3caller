// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Helpers} from "../helpers/Helpers.sol";
import {C3DappManager} from "../../src/dapp/C3DappManager.sol";
import {IC3DAppManager} from "../../src/dapp/IC3DappManager.sol";
import {IC3GovClient} from "../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";

contract C3DappManagerTest is Helpers {
    C3DappManager public dappManager;
    string public mpcAddr1 = "0x1234567890123456789012345678901234567890";
    string public pubKey1 = "0x0987654321098765432109876543210987654321";
    string public mpcAddr2 = "0x1234567890123456789012345678901234567891";
    string public pubKey2 = "0x0987654321098765432109876543210987654322";
    string public mpcAddr3 = "0x1234567890123456789012345678901234567892";
    string public pubKey3 = "0x0987654321098765432109876543210987654323";

    function setUp() public override {
        super.setUp();
        vm.prank(gov);
        dappManager = new C3DappManager();
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public view {
        console.log("Expected gov address:", gov);
        console.log("Actual gov address:", dappManager.gov());
        assertEq(dappManager.gov(), gov);
        assertEq(dappManager.dappID(), 0);
    }

    // ============ PAUSE/UNPAUSE TESTS ============

    function test_Pause_Success() public {
        vm.prank(gov);
        dappManager.pause();
        assertTrue(dappManager.paused());
    }

    function test_Pause_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(gov);
        dappManager.pause();
        
        vm.prank(gov);
        dappManager.unpause();
        assertFalse(dappManager.paused());
    }

    function test_Unpause_OnlyGov() public {
        vm.prank(gov);
        dappManager.pause();
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.unpause();
    }

    // ============ BLACKLIST TESTS ============

    function test_SetBlacklists_Success() public {
        vm.prank(gov);
        dappManager.setBlacklists(1, true);
        
        assertTrue(dappManager.appBlacklist(1));
        
        vm.prank(gov);
        dappManager.setBlacklists(1, false);
        
        assertFalse(dappManager.appBlacklist(1));
    }

    function test_SetBlacklists_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.setBlacklists(1, true);
    }

    // ============ DAPP CONFIG TESTS ============

    function test_SetDAppConfig_Success() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        IC3DAppManager.DappConfig memory config = dappManager.getDappConfig(1);
        assertEq(config.id, 1);
        assertEq(config.appAdmin, user1);
        assertEq(config.feeToken, address(usdc));
        assertEq(config.discount, 0);
    }

    function test_SetDAppConfig_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
    }

    function test_SetDAppConfig_ZeroFeeToken() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.FeePerByte
            )
        );
        dappManager.setDAppConfig(1, user1, address(0), "test.com", "test@test.com");
    }

    function test_SetDAppConfig_EmptyAppDomain() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.AppDomain
            )
        );
        dappManager.setDAppConfig(1, user1, address(usdc), "", "test@test.com");
    }

    function test_SetDAppConfig_EmptyEmail() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.Email
            )
        );
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "");
    }

    function test_SetDappConfigDiscount_Success() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        dappManager.setDappConfigDiscount(1, 10);
        
        IC3DAppManager.DappConfig memory config = dappManager.getDappConfig(1);
        assertEq(config.discount, 10);
    }

    function test_SetDappConfigDiscount_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.setDappConfigDiscount(1, 10);
    }

    function test_SetDappConfigDiscount_ZeroDappID() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.DAppID
            )
        );
        dappManager.setDappConfigDiscount(0, 10);
    }

    function test_SetDappConfigDiscount_ZeroDiscount() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_LengthMismatch.selector,
                C3ErrorParam.DAppID,
                C3ErrorParam.Token
            )
        );
        dappManager.setDappConfigDiscount(1, 0);
    }

    // ============ DAPP ADDRESS TESTS ============

    function test_SetDAppAddr_Success() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        string[] memory addresses = new string[](2);
        addresses[0] = "addr1";
        addresses[1] = "addr2";
        
        vm.prank(gov);
        dappManager.setDAppAddr(1, addresses);
        
        assertEq(dappManager.c3DappAddr("addr1"), 1);
        assertEq(dappManager.c3DappAddr("addr2"), 1);
    }

    function test_SetDAppAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        string[] memory addresses = new string[](1);
        addresses[0] = "addr1";
        
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.setDAppAddr(1, addresses);
    }

    function test_SetDAppAddr_ByAdmin() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        string[] memory addresses = new string[](1);
        addresses[0] = "addr1";
        
        vm.prank(user1);
        dappManager.setDAppAddr(1, addresses);
        
        assertEq(dappManager.c3DappAddr("addr1"), 1);
    }

    // ============ MPC ADDRESS TESTS ============

    function test_AddMpcAddr_Success() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
        
        assertEq(dappManager.getMpcPubkey(1, mpcAddr1), pubKey1);
        string[] memory addrs = dappManager.getMpcAddrs(1);
        assertEq(addrs.length, 1);
        assertEq(addrs[0], mpcAddr1);
    }

    function test_AddMpcAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
    }

    function test_AddMpcAddr_ZeroAppAdmin() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZeroAddress.selector,
                C3ErrorParam.Admin
            )
        );
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
    }

    function test_AddMpcAddr_EmptyAddr() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZeroAddress.selector,
                C3ErrorParam.Admin
            )
        );
        dappManager.addMpcAddr(1, "", "pubkey1");
    }

    function test_AddMpcAddr_EmptyPubkey() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZeroAddress.selector,
                C3ErrorParam.Admin
            )
        );
        dappManager.addMpcAddr(1, mpcAddr1, "");
    }

    function test_AddMpcAddr_LengthMismatch() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_LengthMismatch.selector,
                C3ErrorParam.Address,
                C3ErrorParam.PubKey
            )
        );
        dappManager.addMpcAddr(1, mpcAddr1, "pubkey123");
    }

    function test_DelMpcAddr_Success() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr2, pubKey2);
        
        vm.prank(gov);
        dappManager.delMpcAddr(1, mpcAddr1, pubKey1);
        
        assertEq(dappManager.getMpcPubkey(1, mpcAddr1), "");
        string[] memory addrs = dappManager.getMpcAddrs(1);
        assertEq(addrs.length, 1);
        assertEq(addrs[0], mpcAddr2);
    }

    function test_DelMpcAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
        
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.delMpcAddr(1, mpcAddr1, pubKey1);
    }

    function test_DelMpcAddr_ZeroAppAdmin() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZeroAddress.selector,
                C3ErrorParam.Admin
            )
        );
        dappManager.delMpcAddr(1, mpcAddr1, pubKey1);
    }

    function test_DelMpcAddr_EmptyAddr() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZeroAddress.selector,
                C3ErrorParam.Admin
            )
        );
        dappManager.delMpcAddr(1, "", pubKey1);
    }

    function test_DelMpcAddr_EmptyPubkey() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZeroAddress.selector,
                C3ErrorParam.Admin
            )
        );
        dappManager.delMpcAddr(1, mpcAddr1, "");
    }

    // ============ FEE CONFIG TESTS ============

    function test_SetFeeConfig_Success() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 100);
        
        assertEq(dappManager.getFeeCurrency(address(usdc)), 100);
        assertEq(dappManager.getSpeChainFee("ethereum", address(usdc)), 100);
    }

    function test_SetFeeConfig_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.setFeeConfig(address(usdc), "ethereum", 100);
    }

    function test_SetFeeConfig_ZeroFee() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.FeePerByte
            )
        );
        dappManager.setFeeConfig(address(usdc), "ethereum", 0);
    }

    // ============ DEPOSIT TESTS ============

    function test_Deposit_Success() public {
        uint256 amount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), amount);
    }

    function test_Deposit_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.FeePerByte
            )
        );
        dappManager.deposit(1, address(usdc), 0);
    }

    function test_Deposit_MultipleDeposits() public {
        uint256 amount1 = 1000;
        uint256 amount2 = 500;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount1 + amount2);
        dappManager.deposit(1, address(usdc), amount1);
        dappManager.deposit(1, address(usdc), amount2);
        vm.stopPrank();
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), amount1 + amount2);
    }

    // ============ WITHDRAW TESTS ============

    function test_Withdraw_Success() public {
        uint256 depositAmount = 1000;
        uint256 withdrawAmount = 500;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(gov);
        dappManager.withdraw(1, address(usdc), withdrawAmount);
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), depositAmount - withdrawAmount);
    }

    function test_Withdraw_OnlyGovOrAdmin() public {
        uint256 depositAmount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.withdraw(1, address(usdc), 500);
    }

    function test_Withdraw_ByAdmin() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        uint256 depositAmount = 1000;
        
        vm.startPrank(user2);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(user1);
        dappManager.withdraw(1, address(usdc), 500);
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), 500);
    }

    function test_Withdraw_ZeroAmount() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.FeePerByte
            )
        );
        dappManager.withdraw(1, address(usdc), 0);
    }

    function test_Withdraw_InsufficientBalance() public {
        uint256 depositAmount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_InsufficientBalance.selector,
                address(usdc)
            )
        );
        dappManager.withdraw(1, address(usdc), 1500);
    }

    // ============ CHARGING TESTS ============

    function test_Charging_Success() public {
        uint256 depositAmount = 1000;
        uint256 chargeAmount = 500;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(gov);
        dappManager.charging(1, address(usdc), chargeAmount);
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), depositAmount - chargeAmount);
    }

    function test_Charging_OnlyGovOrAdmin() public {
        uint256 depositAmount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.charging(1, address(usdc), 500);
    }

    function test_Charging_ByAdmin() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        uint256 depositAmount = 1000;
        
        vm.startPrank(user2);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(user1);
        dappManager.charging(1, address(usdc), 500);
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), 500);
    }

    function test_Charging_ZeroAmount() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.FeePerByte
            )
        );
        dappManager.charging(1, address(usdc), 0);
    }

    function test_Charging_InsufficientBalance() public {
        uint256 depositAmount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_InsufficientBalance.selector,
                address(usdc)
            )
        );
        dappManager.charging(1, address(usdc), 1500);
    }

    // ============ VIEW FUNCTION TESTS ============

    function test_GetDappConfig_Empty() public view {
        IC3DAppManager.DappConfig memory config = dappManager.getDappConfig(1);
        assertEq(config.id, 0);
        assertEq(config.appAdmin, address(0));
        assertEq(config.feeToken, address(0));
        assertEq(config.discount, 0);
    }

    function test_GetDappConfig_WithData() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        IC3DAppManager.DappConfig memory config = dappManager.getDappConfig(1);
        assertEq(config.id, 1);
        assertEq(config.appAdmin, user1);
        assertEq(config.feeToken, address(usdc));
        assertEq(config.discount, 0);
    }

    function test_GetMpcAddrs_Empty() public view {
        string[] memory addrs = dappManager.getMpcAddrs(1);
        assertEq(addrs.length, 0);
    }

    function test_GetMpcAddrs_WithData() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr2, pubKey2);
        
        string[] memory addrs = dappManager.getMpcAddrs(1);
        assertEq(addrs.length, 2);
        assertEq(addrs[0], mpcAddr1);
        assertEq(addrs[1], mpcAddr2);
    }

    function test_GetMpcPubkey_Empty() public view {
        assertEq(dappManager.getMpcPubkey(1, mpcAddr1), "");
    }

    function test_GetMpcPubkey_WithData() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
        
        assertEq(dappManager.getMpcPubkey(1, mpcAddr1), pubKey1);
    }

    function test_GetFeeCurrency_Empty() public view {
        assertEq(dappManager.getFeeCurrency(address(usdc)), 0);
    }

    function test_GetFeeCurrency_WithData() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 100);
        
        assertEq(dappManager.getFeeCurrency(address(usdc)), 100);
    }

    function test_GetSpeChainFee_Empty() public view {
        assertEq(dappManager.getSpeChainFee("ethereum", address(usdc)), 0);
    }

    function test_GetSpeChainFee_WithData() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 100);
        
        assertEq(dappManager.getSpeChainFee("ethereum", address(usdc)), 100);
    }

    function test_GetDappStakePool_Empty() public view {
        assertEq(dappManager.getDappStakePool(1, address(usdc)), 0);
    }

    function test_GetDappStakePool_WithData() public {
        uint256 amount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), amount);
    }

    // ============ FEE MANAGEMENT TESTS ============

    function test_SetFee_Success() public {
        vm.prank(gov);
        dappManager.setFee(address(usdc), 100);
        
        assertEq(dappManager.getFee(address(usdc)), 100);
    }

    function test_SetFee_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.setFee(address(usdc), 100);
    }

    function test_GetFee_Empty() public view {
        assertEq(dappManager.getFee(address(usdc)), 0);
    }

    function test_GetFee_WithData() public {
        vm.prank(gov);
        dappManager.setFee(address(usdc), 100);
        
        assertEq(dappManager.getFee(address(usdc)), 100);
    }

    // ============ DAPP ID TESTS ============

    function test_SetDappID_Success() public {
        vm.prank(gov);
        dappManager.setDappID(123);
        
        assertEq(dappManager.dappID(), 123);
    }

    function test_SetDappID_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.setDappID(123);
    }

    // ============ EDGE CASES ============

    function test_MultipleDapps() public {
        // Setup multiple dapps
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "dapp1.com", "dapp1@test.com");
        
        vm.prank(gov);
        dappManager.setDAppConfig(2, user2, address(ctm), "dapp2.com", "dapp2@test.com");
        
        // Verify they don't interfere
        IC3DAppManager.DappConfig memory config1 = dappManager.getDappConfig(1);
        IC3DAppManager.DappConfig memory config2 = dappManager.getDappConfig(2);
        
        assertEq(config1.appAdmin, user1);
        assertEq(config1.feeToken, address(usdc));
        assertEq(config2.appAdmin, user2);
        assertEq(config2.feeToken, address(ctm));
    }

    function test_MultipleTokens() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 100);
        
        vm.prank(gov);
        dappManager.setFeeConfig(address(ctm), "ethereum", 200);
        
        assertEq(dappManager.getFeeCurrency(address(usdc)), 100);
        assertEq(dappManager.getFeeCurrency(address(ctm)), 200);
    }

    function test_MultipleChains() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 100);
        
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "polygon", 150);
        
        assertEq(dappManager.getSpeChainFee("ethereum", address(usdc)), 100);
        assertEq(dappManager.getSpeChainFee("polygon", address(usdc)), 150);
    }

    // ============ STRESS TESTS ============

    function test_MultipleMpcAddresses() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        // Add multiple MPC addresses
        // for (uint256 i = 0; i < 10; i++) {
        //     vm.prank(gov);
        //     dappManager.addMpcAddr(1, string(abi.encodePacked("mpc", i)), string(abi.encodePacked("pubkey", i)));
        // }
        vm.startPrank(gov);
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
        dappManager.addMpcAddr(1, mpcAddr2, pubKey2);
        dappManager.addMpcAddr(1, mpcAddr3, pubKey3);
        vm.stopPrank();
        
        string[] memory addrs = dappManager.getMpcAddrs(1);
        assertEq(addrs.length, 3);
        
        // Remove some addresses
        vm.prank(gov);
        dappManager.delMpcAddr(1, mpcAddr1, pubKey1);
        
        addrs = dappManager.getMpcAddrs(1);
        assertEq(addrs.length, 2);
    }

    function test_MultipleDepositsAndWithdrawals() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        uint256 totalDeposited = 0;
        
        // Multiple deposits
        for (uint256 i = 0; i < 5; i++) {
            uint256 amount = 100 * (i + 1);
            totalDeposited += amount;
            
            vm.startPrank(user1);
            usdc.approve(address(dappManager), amount);
            dappManager.deposit(1, address(usdc), amount);
            vm.stopPrank();
        }
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), totalDeposited);
        
        // Multiple withdrawals
        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 amount = 50 * (i + 1);
            totalWithdrawn += amount;
            
            vm.prank(gov);
            dappManager.withdraw(1, address(usdc), amount);
        }
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), totalDeposited - totalWithdrawn);
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function test_Gas_SetDAppConfig() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for setDAppConfig:", gasUsed);
    }

    function test_Gas_Deposit() public {
        uint256 amount = 1000;
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        
        uint256 gasBefore = gasleft();
        dappManager.deposit(1, address(usdc), amount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        console.log("Gas used for deposit:", gasUsed);
    }

    function test_Gas_Withdraw() public {
        uint256 amount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();
        
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        dappManager.withdraw(1, address(usdc), 500);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for withdraw:", gasUsed);
    }

    function test_Gas_AddMpcAddr() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        dappManager.addMpcAddr(1, mpcAddr1, pubKey1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for addMpcAddr:", gasUsed);
    }
}
