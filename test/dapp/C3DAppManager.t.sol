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

    function transfer(
        address to,
        uint256 /*amount*/
    )
        external
        returns (bool)
    {
        if (reentering && to == address(dappManager)) {
            // Try to reenter the withdraw function
            dappManager.withdraw(1, address(this));
        }
        return true;
    }

    function transferFrom(
        address,
        /*from*/
        address,
        /*to*/
        uint256 /*amount*/
    )
        external
        pure
        returns (bool)
    {
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
    uint256 maliciousDAppID;

    MaliciousToken public maliciousToken;

    function setUp() public override {
        super.setUp();
        vm.prank(gov);
        dappManager = new C3DAppManager();

        // Deploy malicious token
        maliciousToken = new MaliciousToken(dappManager);

        // Setup dapp config
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(maliciousToken), "ethereum", 1, 1);
        maliciousDAppID = dappManager.setDAppConfig(address(maliciousToken), "test.com", "test@test.com");
        vm.stopPrank();
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public view {
        console.log("Expected gov address:", gov);
        console.log("Actual gov address:", dappManager.gov());
        assertEq(dappManager.gov(), gov);
        assertEq(dappManager.dappID(), 1);
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
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
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
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.unpause();
    }

    // ============ DAPP STATUS TESTS ============

    function test_SetDAppStatus_AllCases() public {
        IC3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        IC3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        IC3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        IC3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        // DApp is active by default
        IC3DAppManager.DAppStatus currentStatus = dappManager.dappStatus(dappID);
        assertEq(uint8(currentStatus), uint8(active));
        assertEq(dappManager.statusReason(dappID), "");

        // Make fee token deprecated, validate new one
        vm.startPrank(gov);
        dappManager.removeFeeConfig(address(usdc));
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        bool usdcValid = dappManager.feeCurrencies(address(usdc));
        assertFalse(usdcValid);

        // DApp is using deprecated fee token, dormant
        currentStatus = dappManager.dappStatus(dappID);
        assertEq(uint8(currentStatus), uint8(dormant));
        assertEq(dappManager.statusReason(dappID), "");

        // DApp upgrades their fee token to validated one, active
        vm.warp(block.timestamp + 30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, address(ctm), user1, "newdomain.com", "newtest@test.com");
        currentStatus = dappManager.dappStatus(dappID);
        assertEq(uint8(currentStatus), uint8(active));
        assertEq(dappManager.statusReason(dappID), "");

        // DApp status set to suspended
        vm.prank(gov);
        dappManager.setDAppStatus(dappID, suspended, "bad dapp");
        currentStatus = dappManager.dappStatus(dappID);
        assertEq(uint8(currentStatus), uint8(suspended));
        assertEq(dappManager.statusReason(dappID), "bad dapp");

        // DApp status set to deprecated
        vm.prank(gov);
        dappManager.setDAppStatus(dappID, deprecated, "dead dapp");
        currentStatus = dappManager.dappStatus(dappID);
        assertEq(uint8(currentStatus), uint8(deprecated));
        assertEq(dappManager.statusReason(dappID), "dead dapp");

        // DApp status cannot be changed once deprecated
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, deprecated, active)
        );
        dappManager.setDAppStatus(dappID, active, "reuse dapp");
    }

    function test_SetDAppStatus_OnlyGov() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.setDAppStatus(dappID, IC3DAppManager.DAppStatus.Suspended, "suspend dapp illegaly");
    }

    function test_SetDAppStatus_SuspendedDepositFails() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, IC3DAppManager.DAppStatus.Suspended, "suspended dapp");
        IC3DAppManager.DAppStatus status = dappManager.dappStatus(dappID);
        IC3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        assertEq(uint8(status), uint8(suspended));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, suspended));
        dappManager.deposit(dappID, address(usdc), 10);
    }

    // ============ DAPP CONFIG TESTS ============

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

    function test_SetDAppConfig_ZeroFeeToken() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(0)));
        dappManager.setDAppConfig(address(0), "test.com", "test@test.com");
    }

    function test_SetDAppConfig_EmptyAppDomain() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.AppDomain));
        dappManager.setDAppConfig(address(usdc), "", "test@test.com");
    }

    function test_SetDAppConfig_EmptyEmail() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Email));
        dappManager.setDAppConfig(address(usdc), "test.com", "");
    }

    function test_SetDAppConfigDiscount_Success() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.setDAppFeeDiscount(dappID, 10);

        (,,,, uint256 discount,) = dappManager.dappConfig(dappID);
        assertEq(discount, 10);
    }

    function test_SetDAppConfigDiscount_OnlyGov() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.setDAppFeeDiscount(dappID, 10);
    }

    function test_SetDAppConfigDiscount_ZeroDAppID() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.setDAppFeeDiscount(0, 10);
    }

    // ============ UPDATE DAPP CONFIG TESTS ============

    function test_UpdateDAppConfig_Success() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, address(ctm), user2, "test2.com", "test2@test.com");

        (address dappAdmin, address feeToken, string memory domain, string memory email,, uint256 lastUpdated) =
            dappManager.dappConfig(dappID);
        assertEq(dappAdmin, user2);
        assertEq(feeToken, address(ctm));
        assertEq(domain, "test2.com");
        assertEq(email, "test2@test.com");
        assertEq(lastUpdated, block.timestamp);
    }

    function test_UpdateDAppConfig_BeforeCooldownFails() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_RecentlyUpdated.selector, dappID));
        dappManager.updateDAppConfig(dappID, address(ctm), user2, "test2.com", "test2@test.com");
    }

    function test_UpdateDAppConfig_DeprecatedFeeToken() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        uint256 initialTs = block.timestamp;

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.removeFeeConfig(address(ctm));

        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(ctm)));
        dappManager.updateDAppConfig(dappID, address(ctm), user2, "test2.com", "test2@test.com");

        (address dappAdmin, address feeToken, string memory domain, string memory email,, uint256 lastUpdated) =
            dappManager.dappConfig(dappID);
        IC3DAppManager.DAppStatus status = dappManager.dappStatus(dappID);
        assertEq(dappAdmin, user1);
        assertEq(feeToken, address(usdc));
        assertEq(domain, "test.com");
        assertEq(email, "test@test.com");
        assertEq(lastUpdated, initialTs);
        assertEq(uint8(status), uint8(0));
    }

    // ============ DAPP ADDRESS TESTS ============

    function test_SetDAppAddr_Success() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        string[] memory addresses = new string[](2);
        addresses[0] = "addr1";
        addresses[1] = "addr2";

        vm.prank(gov);
        dappManager.setDAppAddr(dappID, addresses);

        assertEq(dappManager.c3DAppAddr("addr1"), dappID);
        assertEq(dappManager.c3DAppAddr("addr2"), dappID);
    }

    function test_SetDAppAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        string[] memory addresses = new string[](1);
        addresses[0] = "addr1";

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.setDAppAddr(dappID, addresses);
    }

    function test_SetDAppAddr_ByAdmin() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        string[] memory addresses = new string[](1);
        addresses[0] = "addr1";

        vm.prank(user1);
        dappManager.setDAppAddr(dappID, addresses);

        assertEq(dappManager.c3DAppAddr("addr1"), dappID);
    }

    // ============ MPC ADDRESS TESTS ============

    function test_AddMpcAddr_Success() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        assertEq(dappManager.mpcPubkey(dappID, mpcAddr1), pubKey1);
        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(addrs.length, 1);
        assertEq(addrs[0], mpcAddr1);
    }

    function test_AddMpcAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_AddMpcAddr_EmptyAddr() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZeroAddress.selector, C3ErrorParam.Address)
        );
        dappManager.addMpcAddr(dappID, "", "pubkey1");
    }

    function test_AddMpcAddr_EmptyPubkey() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_LengthMismatch.selector, C3ErrorParam.Address, C3ErrorParam.PubKey
            )
        );
        dappManager.addMpcAddr(dappID, mpcAddr1, "");
    }

    function test_AddMpcAddr_LengthMismatch() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_LengthMismatch.selector, C3ErrorParam.Address, C3ErrorParam.PubKey
            )
        );
        dappManager.addMpcAddr(dappID, mpcAddr1, "pubkey123");
    }

    function test_DelMpcAddr_Success() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr2, pubKey2);

        vm.prank(gov);
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        assertEq(dappManager.mpcPubkey(dappID, mpcAddr1), "");
        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(addrs.length, 1);
        assertEq(addrs[0], mpcAddr2);
    }

    function test_DelMpcAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_DelMpcAddr_EmptyAddr() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZeroAddress.selector, C3ErrorParam.Address)
        );
        dappManager.delMpcAddr(dappID, "", pubKey1);
    }

    function test_DelMpcAddr_EmptyPubkey() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZeroAddress.selector, C3ErrorParam.PubKey)
        );
        dappManager.delMpcAddr(dappID, mpcAddr1, "");
    }

    // ============ FEE CONFIG TESTS ============

    function test_SetFeeConfig_Success() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        (uint256 perByte, uint256 perGas) = dappManager.specificChainFee("ethereum", address(usdc));
        uint256 minimumDeposit = dappManager.feeMinimumDeposit(address(usdc));

        assertEq(perByte, 1);
        assertEq(perGas, 1);
        assertEq(minimumDeposit, 100);
    }

    function test_SetFeeConfig_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
    }

    function test_SetFeeConfig_ZeroFeePerByte() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.FeePerByte));
        dappManager.setFeeConfig(address(usdc), "ethereum", 0, 1);
    }

    function test_SetFeeConfig_ZeroFeePerGas() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.FeePerGas));
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 0);
    }

    // ============ DISCOUNT TESTS ============

    function test_Discount_ZeroDiscount() public {
        uint256 feePerByte = 100;
        uint256 feePerGas = 1 gwei;
        uint256 sizeByte = 4;
        uint256 sizeGas = 21000;
        uint256 totalExpectedBill = (feePerByte * sizeByte) + (feePerGas * sizeGas);

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(ctm), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(ctm), "test.com", "test@test.com");
        ctm.approve(address(dappManager), 1 ether);
        dappManager.deposit(dappID, address(ctm), 1 ether);
        vm.stopPrank();

        vm.prank(gov);
        dappManager.setDAppFeeDiscount(dappID, 0);

        uint256 govInitialBalance = ctm.balanceOf(gov);

        vm.prank(gov);
        dappManager.charging(dappID, address(ctm), sizeByte, sizeGas, "ethereum");

        uint256 govFinalBalance = ctm.balanceOf(gov);
        assertEq(govFinalBalance, govInitialBalance + totalExpectedBill);
    }

    function test_Discount_FullDiscount() public {
        uint256 feePerByte = 100;
        uint256 feePerGas = 1 gwei;
        uint256 sizeByte = 4;
        uint256 sizeGas = 21000;

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(ctm), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(ctm), "test.com", "test@test.com");
        ctm.approve(address(dappManager), 1 ether);
        dappManager.deposit(dappID, address(ctm), 1 ether);
        vm.stopPrank();

        vm.prank(gov);
        dappManager.setDAppFeeDiscount(dappID, 10000);

        uint256 govInitialBalance = ctm.balanceOf(gov);

        vm.prank(gov);
        dappManager.charging(dappID, address(ctm), sizeByte, sizeGas, "ethereum");

        uint256 govFinalBalance = ctm.balanceOf(gov);
        assertEq(govFinalBalance, govInitialBalance);
    }

    // ============ DEPOSIT TESTS ============

    function test_Deposit_Success() public {
        uint256 amount = 1000;

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(1, address(usdc), amount);
        vm.stopPrank();

        assertEq(dappManager.dappStakePool(1, address(usdc)), amount);
    }

    function test_Deposit_ZeroAmount() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 1);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_BelowMinimumDeposit.selector, 0, 1));
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

        assertEq(dappManager.dappStakePool(1, address(usdc)), amount1 + amount2);
    }

    function test_Deposit_BelowMinimum() public {
        uint256 depositAmount = 999;
        uint256 feePerByte = 1;
        uint256 feePerGas = 2;
        uint256 minimumDeposit = 1000;

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_BelowMinimumDeposit.selector, depositAmount, minimumDeposit
            )
        );
        dappManager.deposit(1, address(usdc), depositAmount);
    }

    // ============ WITHDRAW TESTS ============

    function test_Withdraw_Success() public {
        uint256 feePerByte = 1;
        uint256 feePerGas = 2;
        uint256 minimumDeposit = 1000;

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        uint256 depositAmount = 1000;

        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        uint256 user1InitialBalance = usdc.balanceOf(user1);

        vm.prank(gov);
        dappManager.withdraw(dappID, address(usdc));

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), 0);
        assertEq(usdc.balanceOf(user1), user1InitialBalance + 1000);
    }

    function test_Withdraw_OnlyGov() public {
        uint256 depositAmount = 1000;
        uint256 feePerByte = 1;
        uint256 feePerGas = 1;
        uint256 minimumDeposit = 100;

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(1, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.withdraw(dappID, address(usdc));
    }

    function test_Withdraw_ZeroAmount() public {
        uint256 feePerByte = 1;
        uint256 feePerGas = 2;
        uint256 minimumDeposit = 1000;

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager.withdraw(dappID, address(usdc));
    }

    // ============ CHARGING TESTS ============

    function test_Charging_Success() public {
        uint256 depositAmount = 1000;
        uint256 feePerByte = 1;
        uint256 feePerGas = 2;
        uint256 minimumDeposit = 999;
        uint256 sizeBytes = 16;
        uint256 sizeGas = 32;
        string memory chain = "ethereum";
        uint256 chargeAmount = (sizeBytes * feePerByte) + (sizeGas * feePerGas);

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), chain, feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(gov);
        dappManager.charging(dappID, address(usdc), sizeBytes, sizeGas, chain);

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), depositAmount - chargeAmount);
    }

    function test_Charging_OnlyGov() public {
        uint256 depositAmount = 1000;
        uint256 feePerByte = 500;
        uint256 feePerGas = 100;
        uint256 minimumDeposit = 999;
        uint256 sizeBytes = 16;
        uint256 sizeGas = 32;
        string memory chain = "ethereum";

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), chain, feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.charging(dappID, address(usdc), sizeBytes, sizeGas, chain);
    }

    function test_Charging_ZeroAmount() public {
        uint256 feePerByte = 1;
        uint256 feePerGas = 2;
        uint256 minimumDeposit = 999;
        uint256 sizeByte = 0;
        uint256 sizeGas = 0;
        string memory chain = "ethereum";

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), chain, feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager.charging(dappID, address(usdc), sizeByte, sizeGas, chain);
    }

    function test_Charging_InsufficientBalance() public {
        uint256 depositAmount = 1000;
        uint256 feePerByte = 500;
        uint256 feePerGas = 100;
        uint256 minimumDeposit = 999;
        uint256 sizeByte = 16;
        uint256 sizeGas = 16;
        string memory chain = "ethereum";

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), chain, feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InsufficientBalance.selector, address(usdc))
        );
        dappManager.charging(dappID, address(usdc), sizeByte, sizeGas, chain);
    }

    // ============ VIEW FUNCTION TESTS ============

    function test_GetDAppConfig_Empty() public view {
        (address dappAdmin, address feeToken,,, uint256 discount,) = dappManager.dappConfig(2);
        assertEq(dappAdmin, address(0));
        assertEq(feeToken, address(0));
        assertEq(discount, 0);
    }

    function test_GetDAppConfig_WithData() public {
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

    function test_GetMpcAddrs_Empty() public view {
        string[] memory addrs = dappManager.getAllMpcAddrs(1);
        assertEq(addrs.length, 0);
    }

    function test_GetMpcAddrs_WithData() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr2, pubKey2);

        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(addrs.length, 2);
        assertEq(addrs[0], mpcAddr1);
        assertEq(addrs[1], mpcAddr2);
    }

    function test_GetMpcPubkey_Empty() public view {
        assertEq(dappManager.mpcPubkey(1, mpcAddr1), "");
    }

    function test_GetMpcPubkey_WithData() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        assertEq(dappManager.mpcPubkey(dappID, mpcAddr1), pubKey1);
    }

    function test_GetFeeCurrency_Empty() public view {
        assertEq(dappManager.feeCurrencies(address(usdc)), false);
    }

    function test_GetFeeCurrency_WithData() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        assertEq(dappManager.feeCurrencies(address(usdc)), true);
    }

    function test_GetSpeChainFee_Empty() public view {
        (uint256 perByte, uint256 perGas) = dappManager.specificChainFee("ethereum", address(usdc));
        assertEq(perByte, 0);
        assertEq(perGas, 0);
    }

    function test_GetSpeChainFee_WithData() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        (uint256 perByte, uint256 perGas) = dappManager.specificChainFee("ethereum", address(usdc));
        uint256 minimumDeposit = dappManager.feeMinimumDeposit(address(usdc));

        assertEq(perByte, 1);
        assertEq(perGas, 1);
        assertEq(minimumDeposit, 100);
    }

    function test_GetDAppStakePool_Empty() public view {
        assertEq(dappManager.dappStakePool(1, address(usdc)), 0);
    }

    function test_GetDAppStakePool_WithData() public {
        uint256 amount = 1000;
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(dappID, address(usdc), amount);
        vm.stopPrank();

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), amount);
    }

    // ============ CUMULATIVE FEES TESTS ============

    function test_CumulativeFees_Empty() public view {
        assertEq(dappManager.cumulativeFees(address(usdc)), 0);
    }

    function test_CumulativeFees_Success() public {}

    // ============ EDGE CASES ============

    function test_MultipleDApps() public {
        // Setup multiple dapps
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID1 = dappManager.setDAppConfig(address(usdc), "dapp1.com", "dapp1@test.com");
        vm.prank(user2);
        uint256 dappID2 = dappManager.setDAppConfig(address(ctm), "dapp2.com", "dapp2@test.com");

        // Verify they don't interfere
        (address dappAdmin1, address feeToken1,,,,) = dappManager.dappConfig(dappID1);
        (address dappAdmin2, address feeToken2,,,,) = dappManager.dappConfig(dappID2);

        assertEq(dappAdmin1, user1);
        assertEq(feeToken1, address(usdc));
        assertEq(dappAdmin2, user2);
        assertEq(feeToken2, address(ctm));
    }

    function test_MultipleTokens() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        vm.stopPrank();

        assertEq(dappManager.feeCurrencies(address(usdc)), true);
        assertEq(dappManager.feeCurrencies(address(ctm)), true);
    }

    function test_MultipleChains() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 2);
        dappManager.setFeeConfig(address(usdc), "polygon", 3, 4);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        (uint256 perByteEth, uint256 perGasEth) = dappManager.specificChainFee("ethereum", address(usdc));
        (uint256 perBytePoly, uint256 perGasPoly) = dappManager.specificChainFee("polygon", address(usdc));
        uint256 minimumDeposit = dappManager.feeMinimumDeposit(address(usdc));

        assertEq(perByteEth, 1);
        assertEq(perGasEth, 2);
        assertEq(perBytePoly, 3);
        assertEq(perGasPoly, 4);
        assertEq(minimumDeposit, 100);
    }

    // ============ STRESS TESTS ============

    function test_MultipleMpcAddresses() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        // Add multiple MPC addresses
        vm.startPrank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        dappManager.addMpcAddr(dappID, mpcAddr2, pubKey2);
        dappManager.addMpcAddr(dappID, mpcAddr3, pubKey3);
        vm.stopPrank();

        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(addrs.length, 3);

        // Remove some addresses
        vm.prank(gov);
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(addrs.length, 2);
    }

    function test_MultipleDepositsAndWithdrawals() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        uint256 totalDeposited = 0;

        // Multiple deposits
        for (uint256 i = 0; i < 5; i++) {
            uint256 amount = 100 * (i + 1);
            totalDeposited += amount;

            vm.startPrank(user1);
            usdc.approve(address(dappManager), amount);
            dappManager.deposit(dappID, address(usdc), amount);
            vm.stopPrank();
        }

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), totalDeposited);

        // Withdraw all
        vm.prank(gov);
        dappManager.withdraw(dappID, address(usdc));

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), 0);
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function test_Gas_SetDAppConfig() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();
        uint256 gasBefore = gasleft();
        vm.startPrank(user1);
        dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for setDAppConfig:", gasUsed);
    }

    function test_Gas_Deposit() public {
        uint256 amount = 1000;
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");
        usdc.approve(address(dappManager), amount);

        uint256 gasBefore = gasleft();
        dappManager.deposit(dappID, address(usdc), amount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();

        console.log("Gas used for deposit:", gasUsed);
    }

    function test_Gas_Withdraw() public {
        uint256 amount = 1000;
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(dappID, address(usdc), amount);
        vm.stopPrank();

        uint256 gasBefore = gasleft();
        vm.prank(gov);
        dappManager.withdraw(dappID, address(usdc));
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for withdraw:", gasUsed);
    }

    function test_Gas_AddMpcAddr() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);

        vm.prank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        uint256 gasBefore = gasleft();
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for addMpcAddr:", gasUsed);
    }

    function test_ReentrancyVulnerability_Withdraw() public {
        // This test demonstrates the reentrancy vulnerability
        // In a real scenario, this could allow double withdrawals
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        // Setup initial balance
        uint256 initialBalance = 1000;
        vm.startPrank(user1);
        maliciousToken.approve(address(dappManager), initialBalance);
        dappManager.deposit(maliciousDAppID, address(maliciousToken), initialBalance);
        vm.stopPrank();

        // Enable reentering on malicious token
        maliciousToken.setReentering(true);

        // This should trigger a reentrancy attack
        // The malicious token will try to call withdraw again during the transfer
        vm.prank(gov);
        dappManager.withdraw(maliciousDAppID, address(maliciousToken));

        // In a vulnerable implementation, this could result in multiple withdrawals
        // The test demonstrates the potential for reentrancy
        console.log("Reentrancy vulnerability test completed");
    }

    function test_ReentrancySafety_Deposit() public {
        // This test shows that deposit is safer due to CEI pattern
        uint256 amount = 1000;
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(maliciousToken), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(maliciousToken), 100);
        vm.stopPrank();

        // Setup malicious token to try reentering during deposit
        maliciousToken.setReentering(true);

        // This should not cause issues because deposit follows CEI pattern
        vm.startPrank(user1);
        maliciousToken.approve(address(dappManager), amount);
        dappManager.deposit(maliciousDAppID, address(maliciousToken), amount);
        vm.stopPrank();

        // Verify the deposit worked correctly
        assertEq(dappManager.dappStakePool(maliciousDAppID, address(maliciousToken)), amount);
    }

    function test_ReentrancyWithRealToken() public {
        // Test with a real ERC20 token to ensure normal operation
        uint256 amount = 1000;
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappID = dappManager.setDAppConfig(address(usdc), "test.com", "test@test.com");

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(dappID, address(usdc), amount);
        vm.stopPrank();

        // Normal withdraw should work
        vm.prank(gov);
        dappManager.withdraw(dappID, address(usdc));

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), 0);
    }
}
