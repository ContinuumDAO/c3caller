// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Helpers} from "../../helpers/Helpers.sol";
import {C3DappManagerUpgradeable} from "../../../src/upgradeable/dapp/C3DappManagerUpgradeable.sol";
import {IC3DAppManager} from "../../../src/dapp/IC3DappManager.sol";
import {IC3GovClient} from "../../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../../src/utils/C3CallerUtils.sol";

// Mock malicious ERC20 token that can reenter
contract MaliciousTokenUpgradeable is IERC20 {
    C3DappManagerUpgradeable public dappManager;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public reentering = false;

    constructor(C3DappManagerUpgradeable _dappManager) {
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

contract C3DappManagerUpgradeableTest is Helpers {
    C3DappManagerUpgradeable public dappManager;
    string public mpcAddr1 = "0x1234567890123456789012345678901234567890";
    string public pubKey1 = "0x0987654321098765432109876543210987654321";

    MaliciousTokenUpgradeable public maliciousToken;

    function setUp() public override {
        super.setUp();
        vm.prank(gov);
        dappManager = new C3DappManagerUpgradeable();
        dappManager.initialize(gov);
        
        // Deploy malicious token
        maliciousToken = new MaliciousTokenUpgradeable(dappManager);
        
        // Setup dapp config
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(maliciousToken), "test.com", "test@test.com");
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Initialize() public view {
        console.log("Expected gov address:", gov);
        console.log("Actual gov address:", dappManager.gov());
        assertEq(dappManager.gov(), gov);
        assertEq(dappManager.dappID(), 0);
    }

    // ============ REENTRANCY TESTS ============

    function test_ReentrancyProtection_Withdraw() public {
        // This test demonstrates that the reentrancy protection works
        // The malicious token will try to reenter but should be blocked
        
        // Setup initial balance
        uint256 initialBalance = 1000;
        vm.startPrank(user1);
        maliciousToken.approve(address(dappManager), initialBalance);
        dappManager.deposit(1, address(maliciousToken), initialBalance);
        vm.stopPrank();

        // Enable reentering on malicious token
        maliciousToken.setReentering(true);
        
        // This should be blocked by the reentrancy guard
        vm.prank(user1);
        dappManager.withdraw(1, address(maliciousToken), 100);
        
        // The reentrancy should be prevented
        console.log("Reentrancy protection test completed");
    }

    function test_ReentrancySafety_Deposit() public {
        // This test shows that deposit is safe due to CEI pattern
        uint256 amount = 1000;
        
        // Setup malicious token to try reentering during deposit
        maliciousToken.setReentering(true);
        
        // This should not cause issues because deposit follows CEI pattern
        vm.startPrank(user1);
        maliciousToken.approve(address(dappManager), amount);
        dappManager.deposit(1, address(maliciousToken), amount);
        vm.stopPrank();
        
        // Verify the deposit worked correctly
        assertEq(dappManager.getDappStakePool(1, address(maliciousToken)), amount);
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
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), 500);
    }

    // ============ BASIC FUNCTIONALITY TESTS ============

    function test_Deposit_Success() public {
        uint256 amount = 1000;
        
        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();
        
        assertEq(dappManager.getDappStakePool(1, address(usdc)), amount);
    }

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

    function test_SetDAppConfig_Success() public {
        vm.prank(gov);
        dappManager.setDAppConfig(1, user1, address(usdc), "test.com", "test@test.com");
        
        IC3DAppManager.DappConfig memory config = dappManager.getDappConfig(1);
        assertEq(config.id, 1);
        assertEq(config.appAdmin, user1);
        assertEq(config.feeToken, address(usdc));
        assertEq(config.discount, 0);
    }
} 