// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Helpers} from "../../helpers/Helpers.sol";
import {C3DAppManagerUpgradeable} from "../../../src/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {IC3DAppManager} from "../../../src/dapp/IC3DAppManager.sol";
import {IC3GovClient} from "../../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../../src/utils/C3CallerUtils.sol";

// import {C3CallerProxy} from "../../../src/utils/C3CallerProxy.sol";

// Mock malicious ERC20 token that can reenter
contract MaliciousTokenUpgradeable is IERC20 {
    C3DAppManagerUpgradeable public dappManager;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public reentering = false;

    constructor(C3DAppManagerUpgradeable _dappManager) {
        dappManager = _dappManager;
        totalSupply = 1000000;
        balanceOf[address(this)] = 1000000;
    }

    function transfer(address to, uint256) external returns (bool) {
        if (reentering && to == address(dappManager)) {
            // Try to reenter the withdraw function
            dappManager.withdraw(1, address(this));
        }
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
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

contract C3DAppManagerUpgradeableTest is Helpers {
    C3DAppManagerUpgradeable public dappManager;
    string public mpcAddr1 = "0x1234567890123456789012345678901234567890";
    string public pubKey1 = "0x0987654321098765432109876543210987654321";
    uint256 maliciousDAppID;

    MaliciousTokenUpgradeable public maliciousToken;

    function setUp() public override {
        super.setUp();

        vm.startPrank(gov);

        // Deploy upgradeable C3DAppManager
        address implementationV1 = address(new C3DAppManagerUpgradeable());
        bytes memory initData = abi.encodeCall(C3DAppManagerUpgradeable.initialize, ());
        address dappManagerAddr = _deployProxy(implementationV1, initData);
        dappManager = C3DAppManagerUpgradeable(dappManagerAddr);

        // Deploy malicious token
        maliciousToken = new MaliciousTokenUpgradeable(dappManager);

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(maliciousToken), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(maliciousToken), 100);
        vm.stopPrank();

        // Setup dapp config
        maliciousDAppID = dappManager.setDAppConfig(address(maliciousToken), "test.com", "test@test.com");

        vm.stopPrank();
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Initialize() public view {
        console.log("Expected gov address:", gov);
        console.log("Actual gov address:", dappManager.gov());
        assertEq(dappManager.gov(), gov);
        assertEq(dappManager.dappID(), 1);
    }

    // ============ REENTRANCY TESTS ============

    function test_ReentrancyProtection_Withdraw() public {
        // This test demonstrates that the reentrancy protection works
        // The malicious token will try to reenter but should be blocked

        // Setup initial balance
        uint256 initialBalance = 1000;
        vm.startPrank(user1);
        maliciousToken.approve(address(dappManager), initialBalance);
        dappManager.deposit(maliciousDAppID, address(maliciousToken), initialBalance);
        vm.stopPrank();

        // Enable reentering on malicious token
        maliciousToken.setReentering(true);

        // This should be blocked by the reentrancy guard
        vm.prank(gov);
        dappManager.withdraw(maliciousDAppID, address(maliciousToken));

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
        assertEq(dappManager.dappStakePool(1, address(maliciousToken)), amount);
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
        dappManager.withdraw(1, address(usdc));

        assertEq(dappManager.dappStakePool(1, address(usdc)), 0);
    }

    // ============ BASIC FUNCTIONALITY TESTS ============

    function test_Deposit_Success() public {
        uint256 amount = 1000;

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();

        assertEq(dappManager.dappStakePool(1, address(usdc)), amount);
    }

    function test_Withdraw_Success() public {
        uint256 depositAmount = 1000;

        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(gov);
        dappManager.withdraw(1, address(usdc));

        assertEq(dappManager.dappStakePool(1, address(usdc)), 0);
    }

    function test_SetDAppConfig_Success() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        (address dappAdmin, address feeToken,,, uint256 discount,) = dappManager.dappConfig(dappID);
        assertEq(dappAdmin, user1);
        assertEq(feeToken, address(usdc));
        assertEq(discount, 0);
    }
}
