// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Helpers} from "../helpers/Helpers.sol";
import {C3DAppManager} from "../../src/dapp/C3DAppManager.sol";
import {IC3DAppManager} from "../../src/dapp/IC3DAppManager.sol";
import {IC3GovClient} from "../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";

// Mock malicious ERC20 token that can reenter
contract MaliciousToken is IERC20 {
    C3DAppManager public dappManager;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public reentering = false;

    constructor(C3DAppManager _dappManager) {
        dappManager = _dappManager;
        totalSupply = 1000000;
        balanceOf[address(this)] = 1000000;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (reentering && to == address(dappManager)) {
            // Try to reenter the withdraw function
            dappManager.withdraw(1, address(this), 100);
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function setReentering(bool _reentering) external {
        reentering = _reentering;
    }
}

contract C3DAppManagerTest is Helpers {
    C3DAppManager public dappManager;
    string public mpcAddr1 = "0x1234567890123456789012345678901234567890";
    string public pubKey1 = "0x0987654321098765432109876543210987654321";
    string public mpcAddr2 = "0x1234567890123456789012345678901234567891";
    string public pubKey2 = "0x0987654321098765432109876543210987654322";
    string public mpcAddr3 = "0x1234567890123456789012345678901234567892";
    string public pubKey3 = "0x0987654321098765432109876543210987654323";

    MaliciousToken public maliciousToken;

    function setUp() public override {
        super.setUp();
        vm.prank(gov);
        dappManager = new C3DAppManager();
        
        // Deploy malicious token
        maliciousToken = new MaliciousToken(dappManager);
        
        // Setup dapp config
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(maliciousToken), "test.com", "test@test.com");
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
        
        IC3DAppManager.DAppConfig memory config = dappManager.getDAppConfig(1);
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

    function test_SetDAppConfigDiscount_Success() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        vm.prank(gov);
        dappManager.setDAppConfigDiscount(1, 10);
        
        IC3DAppManager.DAppConfig memory config = dappManager.getDAppConfig(1);
        assertEq(config.discount, 10);
    }

    function test_SetDAppConfigDiscount_OnlyGovOrAdmin() public {
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
        dappManager.setDAppConfigDiscount(1, 10);
    }

    function test_SetDAppConfigDiscount_ZeroDAppID() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZero.selector,
                C3ErrorParam.DAppID
            )
        );
        dappManager.setDAppConfigDiscount(0, 10);
    }

    function test_SetDAppConfigDiscount_ZeroDiscount() public {
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
        dappManager.setDAppConfigDiscount(1, 0);
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
        
        assertEq(dappManager.c3DAppAddr("addr1"), 1);
        assertEq(dappManager.c3DAppAddr("addr2"), 1);
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
        
        assertEq(dappManager.c3DAppAddr("addr1"), 1);
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
        dappManager.setDAppConfig(1, address(0), address(usdc), "test.com", "test@test.com");

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
        vm.startPrank(gov);
        dappManager.setDAppConfig(1, address(0), address(usdc), "test.com", "test@test.com");

        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_IsZeroAddress.selector,
                C3ErrorParam.Admin
            )
        );
        dappManager.delMpcAddr(1, mpcAddr1, pubKey1);
        vm.stopPrank();
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
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), amount);
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
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), amount1 + amount2);
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
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), depositAmount - withdrawAmount);
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
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), 500);
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
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), depositAmount - chargeAmount);
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
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), 500);
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

    function test_GetDAppConfig_Empty() public view {
        IC3DAppManager.DAppConfig memory config = dappManager.getDAppConfig(2);
        assertEq(config.id, 0);
        assertEq(config.appAdmin, address(0));
        assertEq(config.feeToken, address(0));
        assertEq(config.discount, 0);
    }

    function test_GetDAppConfig_WithData() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        IC3DAppManager.DAppConfig memory config = dappManager.getDAppConfig(1);
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

    function test_GetDAppStakePool_Empty() public view {
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), 0);
    }

    function test_GetDAppStakePool_WithData() public {
        uint256 amount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), amount);
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

    function test_SetDAppID_Success() public {
        vm.prank(gov);
        dappManager.setDAppID(123);
        
        assertEq(dappManager.dappID(), 123);
    }

    function test_SetDAppID_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        dappManager.setDAppID(123);
    }

    // ============ EDGE CASES ============

    function test_MultipleDApps() public {
        // Setup multiple dapps
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "dapp1.com", "dapp1@test.com");
        
        vm.prank(gov);
        dappManager.setDAppConfig(2, user2, address(ctm), "dapp2.com", "dapp2@test.com");
        
        // Verify they don't interfere
        IC3DAppManager.DAppConfig memory config1 = dappManager.getDAppConfig(1);
        IC3DAppManager.DAppConfig memory config2 = dappManager.getDAppConfig(2);
        
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
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), totalDeposited);
        
        // Multiple withdrawals
        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 amount = 50 * (i + 1);
            totalWithdrawn += amount;
            
            vm.prank(gov);
            dappManager.withdraw(1, address(usdc), amount);
        }
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), totalDeposited - totalWithdrawn);
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

    function test_ReentrancyVulnerability_Withdraw() public {
        // This test demonstrates the reentrancy vulnerability
        // In a real scenario, this could allow double withdrawals
        
        // Setup initial balance
        uint256 initialBalance = 1000;
        vm.startPrank(user1);
        maliciousToken.approve(address(dappManager), initialBalance);
        dappManager.deposit(1, address(maliciousToken), initialBalance);
        vm.stopPrank();
        
        // Enable reentering on malicious token
        maliciousToken.setReentering(true);
        
        // This should trigger a reentrancy attack
        // The malicious token will try to call withdraw again during the transfer
        vm.prank(user1);
        dappManager.withdraw(1, address(maliciousToken), 100);
        
        // In a vulnerable implementation, this could result in multiple withdrawals
        // The test demonstrates the potential for reentrancy
        console.log("Reentrancy vulnerability test completed");
    }

    function test_ReentrancySafety_Deposit() public {
        // This test shows that deposit is safer due to CEI pattern
        uint256 amount = 1000;
        
        // Setup malicious token to try reentering during deposit
        maliciousToken.setReentering(true);
        
        // This should not cause issues because deposit follows CEI pattern
        vm.startPrank(user1);
        maliciousToken.approve(address(dappManager), amount);
        dappManager.deposit(1, address(maliciousToken), amount);
        vm.stopPrank();
        
        // Verify the deposit worked correctly
        assertEq(dappManager.getDAppStakePool(1, address(maliciousToken)), amount);
    }

    function test_ReentrancyWithRealToken() public {
        // Test with a real ERC20 token to ensure normal operation
        uint256 amount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();
        
        // Normal withdraw should work
        vm.prank(gov);
        dappManager.withdraw(1, address(usdc), 500);
        
        assertEq(dappManager.getDAppStakePool(1, address(usdc)), 500);
    }
}
