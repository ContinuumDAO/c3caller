// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

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
    uint256 dappID;
    uint256 maliciousDAppID;

    string c3pingMetadata =
        "{'version':1,'name':'C3Ping','description':'Ping other networks with C3Caller','email':'admin@c3ping.com','url':'c3ping.com'}";
    string assetXMetadata =
        "{'version':1,'name':'CTMRWA1X','description':'AssetX: Cross-chain transfers','email':'admin@assetx.com','url':'assetx.org'}";
    string c3governorMetadata =
        "{'version':1,'name':'C3Governor','description':'Cross-chain governance','email':'admin@c3gov.com','url':'c3gov.com'}";
    string maliciousMetadata =
        "{'version':1,'name':'MaliciousDApp','description':'Steal your money','email':'admin@malice.com','url':'malice.com'}";

    MaliciousToken public maliciousToken;

    function setUp() public override {
        super.setUp();
        vm.prank(gov);
        dappManager = new C3DAppManager();

        // Deploy malicious token
        maliciousToken = new MaliciousToken(dappManager);

        // Setup dapp config
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);

        dappManager.setFeeConfig(address(maliciousToken), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(maliciousToken), 100);
        vm.stopPrank();

        vm.prank(user1);
        dappID = dappManager.setDAppConfig(address(usdc), c3pingMetadata);

        vm.prank(user2);
        maliciousDAppID = dappManager.setDAppConfig(address(maliciousToken), maliciousMetadata);
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public {
        assertEq(dappManager.gov(), gov);
        assertEq(dappManager.dappID(), 2); // 2 DApps already registered
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

    // ============ SET DAPP STATUS TESTS ============

    function test_SetDAppStatus_AllCases() public {
        IC3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        IC3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        IC3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        IC3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

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
        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(ctm), c3pingMetadata);
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

    function test_SetDAppStatus_ZeroDAppID() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.setDAppStatus(0, IC3DAppManager.DAppStatus.Suspended, "suspend dapp zero");
    }

    function test_SetDAppStatus_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.setDAppStatus(dappID, IC3DAppManager.DAppStatus.Suspended, "suspend dapp illegaly");
    }

    function test_SetDAppStatus_SuspendedDepositFails() public {
        vm.prank(gov);
        dappManager.setDAppStatus(dappID, IC3DAppManager.DAppStatus.Suspended, "suspended dapp");
        IC3DAppManager.DAppStatus status = dappManager.dappStatus(dappID);
        IC3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        assertEq(uint8(status), uint8(suspended));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, suspended));
        dappManager.deposit(dappID, address(usdc), 10);
    }

    function test_SetDAppStatus_InvalidStatusTransition() public {
        uint256 dappID2 = dappManager.setDAppConfig(address(usdc), c3pingMetadata);
        uint256 dappID3 = dappManager.setDAppConfig(address(usdc), assetXMetadata);

        IC3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        IC3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        IC3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        IC3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

        vm.startPrank(gov);
        // active -> active (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, active, active)
        );
        dappManager.setDAppStatus(dappID, active, "active dapp");

        // active -> suspended (valid)
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.DAppStatusChanged(dappID, active, suspended, "suspend dapp");
        dappManager.setDAppStatus(dappID, suspended, "suspend dapp");

        // suspended -> dormant (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, suspended, dormant)
        );
        dappManager.setDAppStatus(dappID, dormant, "dormant dapp");

        // suspended -> suspended (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, suspended, suspended)
        );
        dappManager.setDAppStatus(dappID, suspended, "suspended dapp");

        // suspended -> active (valid)
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.DAppStatusChanged(dappID, suspended, active, "active dapp");
        dappManager.setDAppStatus(dappID, active, "active dapp");

        // active -> dormant (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, active, dormant)
        );
        dappManager.setDAppStatus(dappID, dormant, "dormant dapp");

        // active -> deprecated (valid)
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.DAppStatusChanged(dappID, active, deprecated, "deprecated dapp");
        dappManager.setDAppStatus(dappID, deprecated, "deprecated dapp");

        // deprecated -> active (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, deprecated, active)
        );
        dappManager.setDAppStatus(dappID, active, "active dapp");

        // deprecated -> suspended (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, deprecated, suspended)
        );
        dappManager.setDAppStatus(dappID, suspended, "active dapp");

        // deprecated -> dormant (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, deprecated, dormant)
        );
        dappManager.setDAppStatus(dappID, dormant, "dormant dapp");

        // deprecated -> deprecated (invalid)
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, deprecated, deprecated
            )
        );
        dappManager.setDAppStatus(dappID, deprecated, "deprecated dapp");

        // suspended -> deprecated (valid)
        dappManager.setDAppStatus(dappID2, suspended, "suspended dapp");
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.DAppStatusChanged(dappID2, suspended, deprecated, "deprecated dapp");
        dappManager.setDAppStatus(dappID2, deprecated, "deprecated dapp");

        dappManager.removeFeeConfig(address(usdc));

        vm.stopPrank();
    }

    function test_DAppStatus_ZeroDAppID() public {
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.dappStatus(0);
    }

    // ============ SET DAPP CONFIG TESTS ============

    function test_SetDAppConfig_Success() public {
        (address dappAdmin, address feeToken, uint256 discount,,) = dappManager.dappConfig(dappID);
        assertEq(dappAdmin, user1);
        assertEq(feeToken, address(usdc));
        assertEq(discount, 0);
        uint256 nextDAppID = dappManager.dappID() + 1;
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.SetDAppConfig(nextDAppID, user1, address(usdc), c3pingMetadata);
        dappManager.setDAppConfig(address(usdc), c3pingMetadata);
    }

    function test_SetDAppConfig_ZeroFeeToken() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(0)));
        dappManager.setDAppConfig(address(0), c3pingMetadata);
    }

    function test_SetDAppConfig_InvalidFeeToken() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(ctm)));
        dappManager.setDAppConfig(address(ctm), c3pingMetadata);
    }

    function test_SetDAppConfig_MetadataEmpty() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Metadata));
        dappManager.setDAppConfig(address(usdc), "");
    }

    function test_SetDAppConfig_MetadataTooLong() public {
        string memory string64Characters = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        string memory string128Characters = string.concat(string64Characters, string64Characters);
        string memory string256Characters = string.concat(string128Characters, string128Characters);
        string memory string512Characters = string.concat(string256Characters, string256Characters);

        vm.prank(user1);
        uint256 dappIDValid = dappManager.setDAppConfig(address(usdc), string512Characters);

        (,,,, string memory metadata) = dappManager.dappConfig(dappIDValid);
        uint256 validLength = bytes(metadata).length;
        assertEq(validLength, bytes(string512Characters).length);

        string memory tooLongMetadata = string.concat(string512Characters, "X");
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_MetadataTooLong.selector,
                bytes(tooLongMetadata).length,
                dappManager.METADATA_LIMIT()
            )
        );
        dappManager.setDAppConfig(address(usdc), tooLongMetadata);
    }

    function test_SetDAppConfig_Paused() public {
        vm.prank(gov);
        dappManager.pause();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        dappManager.setDAppConfig(address(usdc), c3pingMetadata);
    }

    // ============ UPDATE DAPP CONFIG TESTS ============

    function test_UpdateDAppConfig_Success() public {
        skip(30 days);
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.SetDAppConfig(dappID, user2, address(usdc), c3pingMetadata);
        dappManager.updateDAppConfig(dappID, user2, address(usdc), c3pingMetadata);

        (address dappAdmin, address feeToken, uint256 discount, uint256 lastUpdated, string memory metadata) =
            dappManager.dappConfig(dappID);
        assertEq(dappAdmin, user2);
        assertEq(feeToken, address(usdc));
        assertEq(discount, 0);
        assertEq(metadata, c3pingMetadata);
        assertEq(lastUpdated, block.timestamp);
    }

    function test_UpdateDAppConfig_ZeroFeeToken() public {
        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(0)));
        dappManager.updateDAppConfig(dappID, user1, address(0), c3pingMetadata);
    }

    function test_UpdateDAppConfig_InvalidFeeToken() public {
        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(ctm)));
        dappManager.updateDAppConfig(dappID, user1, address(ctm), c3pingMetadata);
    }

    function test_UpdateDAppConfig_MetadataEmpty() public {
        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Metadata));
        dappManager.updateDAppConfig(dappID, user1, address(usdc), "");
    }

    function test_UpdateDAppConfig_MetadataTooLong() public {
        string memory string64Characters = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        string memory string128Characters = string.concat(string64Characters, string64Characters);
        string memory string256Characters = string.concat(string128Characters, string128Characters);
        string memory string512Characters = string.concat(string256Characters, string256Characters);

        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(usdc), string512Characters);

        (,,,, string memory metadata) = dappManager.dappConfig(dappID);
        uint256 validLength = bytes(metadata).length;
        assertEq(validLength, bytes(string512Characters).length);

        string memory tooLongMetadata = string.concat(string512Characters, "X");
        skip(30 days);
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_MetadataTooLong.selector,
                bytes(tooLongMetadata).length,
                dappManager.METADATA_LIMIT()
            )
        );
        dappManager.updateDAppConfig(dappID, user1, address(usdc), tooLongMetadata);
        vm.stopPrank();

        (,,,, metadata) = dappManager.dappConfig(dappID);
        uint256 sameLength = bytes(metadata).length;
        assertEq(sameLength, bytes(string512Characters).length);
    }

    function test_UpdateDAppConfig_BeforeCooldownFails() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_RecentlyUpdated.selector, dappID));
        dappManager.updateDAppConfig(dappID, user2, address(usdc), assetXMetadata);
    }

    function test_UpdateDAppConfig_DeprecatedFeeToken() public {
        uint256 initialTs = block.timestamp;

        vm.prank(gov);
        dappManager.removeFeeConfig(address(usdc));

        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(usdc)));
        dappManager.updateDAppConfig(dappID, user2, address(usdc), assetXMetadata);

        (address dappAdmin, address feeToken, uint256 discount, uint256 lastUpdated, string memory metadata) =
            dappManager.dappConfig(dappID);
        IC3DAppManager.DAppStatus status = dappManager.dappStatus(dappID);
        assertEq(dappAdmin, user1);
        assertEq(feeToken, address(usdc));
        assertEq(discount, 0);
        assertEq(metadata, c3pingMetadata);
        assertEq(lastUpdated, initialTs);
        assertEq(uint8(status), uint8(IC3DAppManager.DAppStatus.Dormant));
    }

    function test_UpdateDAppConfig_OnlyGovOrAdmin() public {
        skip(30 days);
        // admin (valid)
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user2, address(usdc), c3pingMetadata);

        // gov (valid)
        vm.prank(gov);
        dappManager.updateDAppConfig(dappID, user1, address(usdc), c3pingMetadata);

        // non-admin (invalid)
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.updateDAppConfig(dappID, user1, address(usdc), c3pingMetadata);
    }

    function test_UpdateDAppConfig_OnlyActiveOrDormantDAppID() public {
        skip(30 days);
        // active dapp (valid)
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(usdc), c3pingMetadata);

        // suspended dapp (invalid)
        vm.prank(gov);
        dappManager.setDAppStatus(dappID, IC3DAppManager.DAppStatus.Suspended, "suspended dapp");

        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, IC3DAppManager.DAppStatus.Suspended
            )
        );
        dappManager.updateDAppConfig(dappID, user1, address(usdc), c3pingMetadata);

        // dormant dapp (valid)
        vm.startPrank(gov);
        dappManager.setDAppStatus(dappID, IC3DAppManager.DAppStatus.Active, "active dapp");
        dappManager.removeFeeConfig(address(usdc));
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        vm.stopPrank();

        IC3DAppManager.DAppStatus status = dappManager.dappStatus(dappID);
        assertEq(uint8(status), uint8(IC3DAppManager.DAppStatus.Dormant));

        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(ctm), c3pingMetadata);

        // deprecated dapp (invalid)
        vm.prank(gov);
        dappManager.setDAppStatus(dappID, IC3DAppManager.DAppStatus.Deprecated, "deprecated dapp");

        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, IC3DAppManager.DAppStatus.Deprecated
            )
        );
        dappManager.updateDAppConfig(dappID, user2, address(ctm), c3pingMetadata);
    }

    function test_UpdateDAppConfig_GovNoCooldown() public {
        (,,, uint256 lastUpdatedGovBefore,) = dappManager.dappConfig(dappID);
        vm.prank(gov);
        dappManager.updateDAppConfig(dappID, user1, address(usdc), assetXMetadata);
        (,,, uint256 lastUpdatedGovAfter,) = dappManager.dappConfig(dappID);
        assertEq(lastUpdatedGovBefore, lastUpdatedGovAfter);

        (,,, uint256 lastUpdatedAdminBefore,) = dappManager.dappConfig(dappID);
        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user2, address(usdc), c3pingMetadata);
        (,,, uint256 lastUpdatedAdminAfter,) = dappManager.dappConfig(dappID);
        assertEq(lastUpdatedAdminBefore + 30 days, lastUpdatedAdminAfter);
    }

    function test_UpdateDAppConfig_Paused() public {
        vm.prank(gov);
        dappManager.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        dappManager.updateDAppConfig(dappID, user2, address(usdc), c3pingMetadata);
    }

    // ============ SET DAPP ADDR TESTS ============

    function test_SetDAppAddr_Success() public {
        string[] memory addresses = new string[](2);
        addresses[0] = "addr1";
        addresses[1] = "addr2";

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.SetDAppAddr(dappID, addresses);
        dappManager.setDAppAddr(dappID, addresses);

        assertEq(dappManager.c3DAppAddr("addr1"), dappID);
        assertEq(dappManager.c3DAppAddr("addr2"), dappID);
    }

    function test_SetDAppAddr_OnlyGovOrAdmin() public {
        string[] memory addresses = new string[](1);
        addresses[0] = "addr1";

        vm.prank(gov);
        dappManager.setDAppAddr(dappID, addresses);

        vm.prank(user1);
        dappManager.setDAppAddr(dappID, addresses);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.setDAppAddr(dappID, addresses);
    }

    function test_SetDAppAddr_ByAdmin() public {
        string[] memory addresses = new string[](1);
        addresses[0] = "addr1";

        vm.prank(user1);
        dappManager.setDAppAddr(dappID, addresses);

        assertEq(dappManager.c3DAppAddr("addr1"), dappID);
    }

    function test_SetDAppAddr_InactiveDApp() public {
        string[] memory addresses = new string[](1);
        addresses[0] = "addr1";
        C3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        C3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        C3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        C3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

        // active dapp (valid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(active));

        vm.prank(user1);
        dappManager.setDAppAddr(dappID, addresses);

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, suspended, "suspended dapp");

        // suspended dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(suspended));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, suspended));
        dappManager.setDAppAddr(dappID, addresses);

        vm.startPrank(gov);
        dappManager.setDAppStatus(dappID, active, "active dapp");
        dappManager.removeFeeConfig(address(usdc));
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        vm.stopPrank();

        // dormant dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(dormant));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, dormant));
        dappManager.setDAppAddr(dappID, addresses);

        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(ctm), assetXMetadata);

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, deprecated, "deprecated dapp");

        // deprecated dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(deprecated));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, deprecated));
        dappManager.setDAppAddr(dappID, addresses);
    }

    // ============ MPC ADDRESS TESTS ============

    function test_AddMpcAddr_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, false, false, false);
        emit IC3DAppManager.AddMpcAddr(dappID, mpcAddr1, pubKey1);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        assertEq(dappManager.mpcPubkey(dappID, mpcAddr1), pubKey1);
        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(dappManager.getMpcCount(dappID), 1);
        assertEq(addrs[0], mpcAddr1);
    }

    function test_AddMpcAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.prank(user1);
        dappManager.addMpcAddr(dappID, mpcAddr2, pubKey2);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_AddMpcAddr_InactiveDApp() public {
        C3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        C3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        C3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        C3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

        // active dapp (valid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(active));

        vm.prank(user1);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, suspended, "suspended dapp");

        // suspended dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(suspended));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, suspended));
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.startPrank(gov);
        dappManager.setDAppStatus(dappID, active, "active dapp");
        dappManager.removeFeeConfig(address(usdc));
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        vm.stopPrank();

        // dormant dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(dormant));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, dormant));
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(ctm), assetXMetadata);

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, deprecated, "deprecated dapp");

        // deprecated dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(deprecated));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, deprecated));
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_AddMpcAddr_EmptyAddr() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZeroAddress.selector, C3ErrorParam.Address)
        );
        dappManager.addMpcAddr(dappID, "", "pubkey1");
    }

    function test_AddMpcAddr_EmptyPubkey() public {
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_LengthMismatch.selector, C3ErrorParam.Address, C3ErrorParam.PubKey
            )
        );
        dappManager.addMpcAddr(dappID, mpcAddr1, "pubkey123");
    }

    function test_AddMpcAddr_MpcAddressExists() public {
        vm.startPrank(user1);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_MpcAddressExists.selector, mpcAddr1));
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_DelMpcAddr_Success() public {
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr2, pubKey2);

        vm.prank(gov);
        vm.expectEmit(true, false, false, true);
        emit IC3DAppManager.DelMpcAddr(dappID, mpcAddr1, pubKey1);
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        assertEq(dappManager.mpcPubkey(dappID, mpcAddr1), "");
        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(dappManager.getMpcCount(dappID), 1);
        assertEq(addrs[0], mpcAddr2);
    }

    function test_DelMpcAddr_OnlyGovOrAdmin() public {
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.prank(gov);
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.prank(user1);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.prank(user1);
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
            )
        );
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_DelMpcAddr_InactiveDApp() public {
        C3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        C3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        C3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        C3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

        // active dapp (valid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(active));

        vm.prank(user1);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.prank(user1);
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, suspended, "suspended dapp");

        // suspended dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(suspended));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, suspended));
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        vm.startPrank(gov);
        dappManager.setDAppStatus(dappID, active, "active dapp");
        dappManager.removeFeeConfig(address(usdc));
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        vm.stopPrank();

        // dormant dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(dormant));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, dormant));
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);

        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(ctm), assetXMetadata);

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, deprecated, "deprecated dapp");

        // deprecated dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(deprecated));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, deprecated));
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_DelMpcAddr_EmptyAddr() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZeroAddress.selector, C3ErrorParam.Address)
        );
        dappManager.delMpcAddr(dappID, "", pubKey1);
    }

    function test_DelMpcAddr_EmptyPubkey() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZeroAddress.selector, C3ErrorParam.PubKey)
        );
        dappManager.delMpcAddr(dappID, mpcAddr1, "");
    }

    function test_DelMpcAddr_MpcAddrDoesNotExist() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_MpcAddressNotFound.selector, mpcAddr1));
        dappManager.delMpcAddr(dappID, mpcAddr1, pubKey1);
    }

    function test_DelMpcAddr_SwapAndPop() public {
        vm.startPrank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        dappManager.addMpcAddr(dappID, mpcAddr2, pubKey2);
        dappManager.addMpcAddr(dappID, mpcAddr3, pubKey3);
        dappManager.delMpcAddr(dappID, mpcAddr2, pubKey2);
        vm.stopPrank();
        bool is1MpcMember = dappManager.mpcMembership(dappID, mpcAddr1);
        bool is2MpcMember = dappManager.mpcMembership(dappID, mpcAddr2);
        bool is3MpcMember = dappManager.mpcMembership(dappID, mpcAddr3);
        assertTrue(is1MpcMember);
        assertFalse(is2MpcMember);
        assertTrue(is3MpcMember);
    }

    // ============ SET FEE CONFIG TESTS ============

    function test_SetFeeConfig_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, true, false, true);
        emit IC3DAppManager.SetFeeConfig(address(ctm), "ethereum", 1, 1);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        (uint256 perByte, uint256 perGas) = dappManager.specificChainFee(address(ctm), "ethereum");

        assertEq(perByte, 1);
        assertEq(perGas, 1);
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

    // ============ SET FEE MINIMUM DEPOSIT ============

    function test_SetFeeMinimumDeposit_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, false, false, true);
        emit IC3DAppManager.SetFeeMinimumDeposit(address(usdc), 1000 ether);
        dappManager.setFeeMinimumDeposit(address(usdc), 1000 ether);

        uint256 minimumDeposit = dappManager.feeMinimumDeposit(address(usdc));
        assertEq(minimumDeposit, 1000 ether);
    }

    function test_SetFeeMinimumDeposit_OnlyGov() public {
        vm.prank(gov);
        dappManager.setFeeMinimumDeposit(address(usdc), 100);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.setFeeMinimumDeposit(address(usdc), 50);
    }

    function test_SetFeeMinimumDeposit_ZeroMinimum() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.MinimumDeposit)
        );
        dappManager.setFeeMinimumDeposit(address(usdc), 0);
    }

    function test_SetFeeMinimumDeposit_InvalidFeeToken() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(ctm)));
        dappManager.setFeeMinimumDeposit(address(ctm), 1000 ether);
    }

    // ============ REMOVE FEE CONFIG ============

    function test_RemoveFeeConfig_Success() public {
        bool usdcIsCurrentBefore = dappManager.feeCurrencies(address(usdc));
        assertTrue(usdcIsCurrentBefore);
        (uint256 feePerByteBefore, uint256 feePerGasBefore) = dappManager.specificChainFee(address(usdc), "ethereum");
        vm.prank(gov);
        vm.expectEmit(true, false, false, false);
        emit IC3DAppManager.DeleteFeeConfig(address(usdc));
        dappManager.removeFeeConfig(address(usdc));
        (uint256 feePerByteAfter, uint256 feePerGasAfter) = dappManager.specificChainFee(address(usdc), "ethereum");
        bool usdcIsCurrentAfter = dappManager.feeCurrencies(address(usdc));
        assertEq(feePerByteAfter, feePerByteBefore);
        assertEq(feePerGasAfter, feePerGasBefore);
        assertFalse(usdcIsCurrentAfter);
    }

    function test_RemoveFeeConfig_OnlyGov() public {
        vm.prank(gov);
        dappManager.removeFeeConfig(address(usdc));

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.removeFeeConfig(address(usdc));
    }

    // ============ DEPOSIT TESTS ============

    function test_Deposit_Success() public {
        uint256 amount = 1000;

        uint256 senderBalanceBefore = usdc.balanceOf(user1);

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        uint256 dappStakePool = dappManager.dappStakePool(dappID, address(usdc));
        vm.expectEmit(true, true, false, true);
        emit IC3DAppManager.Deposit(dappID, address(usdc), amount, dappStakePool + amount);
        dappManager.deposit(dappID, address(usdc), amount);
        vm.stopPrank();

        uint256 senderBalanceAfter = usdc.balanceOf(user1);

        assertEq(senderBalanceAfter, senderBalanceBefore - amount);
        assertEq(dappManager.dappStakePool(dappID, address(usdc)), amount);
    }

    function test_Deposit_MultipleDeposits() public {
        uint256 amount1 = 1000;
        uint256 amount2 = 500;

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount1 + amount2);
        dappManager.deposit(dappID, address(usdc), amount1);
        dappManager.deposit(dappID, address(usdc), amount2);
        vm.stopPrank();

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), amount1 + amount2);
    }

    function test_Deposit_Paused() public {
        vm.prank(gov);
        dappManager.pause();
        vm.startPrank(user1);
        usdc.approve(address(dappManager), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        dappManager.deposit(dappID, address(usdc), 1 ether);
        vm.stopPrank();
    }

    function test_Deposit_ZeroDAppID() public {
        vm.startPrank(user1);
        usdc.approve(address(dappManager), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.deposit(0, address(usdc), 1 ether);
    }

    function test_Deposit_InactiveDApp() public {
        C3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        C3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        C3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        C3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

        // active dapp (valid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(active));

        vm.startPrank(user1);
        usdc.approve(address(dappManager), 400);
        dappManager.deposit(dappID, address(usdc), 400);
        vm.stopPrank();

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, suspended, "suspended dapp");

        // suspended dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(suspended));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, suspended));
        dappManager.deposit(dappID, address(usdc), 100);

        vm.startPrank(gov);
        dappManager.setDAppStatus(dappID, active, "active dapp");
        dappManager.removeFeeConfig(address(usdc));
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        vm.stopPrank();

        // dormant dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(dormant));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, dormant));
        dappManager.deposit(dappID, address(usdc), 100);

        skip(30 days);
        vm.prank(user1);
        dappManager.updateDAppConfig(dappID, user1, address(ctm), assetXMetadata);

        vm.prank(gov);
        dappManager.setDAppStatus(dappID, deprecated, "deprecated dapp");

        // deprecated dapp (invalid)
        assertEq(uint8(dappManager.dappStatus(dappID)), uint8(deprecated));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InactiveDApp.selector, dappID, deprecated));
        dappManager.deposit(dappID, address(usdc), 100);
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
        dappManager.deposit(dappID, address(usdc), depositAmount);
    }

    // ============ WITHDRAW TESTS ============

    function test_Withdraw_Success() public {
        uint256 depositAmount = 1000;

        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        emit IC3DAppManager.Withdraw(dappID, address(usdc), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        uint256 user1InitialBalance = usdc.balanceOf(user1);

        vm.prank(gov);
        dappManager.withdraw(dappID, address(usdc));

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), 0);
        assertEq(usdc.balanceOf(user1), user1InitialBalance + depositAmount);
    }

    function test_Withdraw_OnlyGov() public {
        uint256 depositAmount = 1000;
        uint256 feePerByte = 1;
        uint256 feePerGas = 1;

        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);

        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.withdraw(dappID, address(usdc));

        vm.prank(gov);
        dappManager.withdraw(dappID, address(usdc));
    }

    function test_Withdraw_ZeroDAppID() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.withdraw(0, address(usdc));
    }

    function test_Withdraw_Paused() public {
        vm.startPrank(gov);
        dappManager.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        dappManager.withdraw(dappID, address(usdc));
    }

    function test_Withdraw_ZeroAmount() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager.withdraw(dappID, address(usdc));
    }

    // ============ CHARGING TESTS ============

    function test_Charging_Success() public {
        uint256 depositAmount = 1000;
        uint256 feePerByte = 1;
        uint256 feePerGas = 2;
        uint256 sizeBytes = 16;
        uint256 sizeGas = 32;
        string memory chain = "ethereum";
        uint256 chargeAmount = (sizeBytes * feePerByte) + (sizeGas * feePerGas);

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);
        vm.stopPrank();

        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(gov);
        vm.expectEmit(true, true, false, true);
        emit IC3DAppManager.Charging(dappID, address(usdc), chargeAmount, 0, depositAmount - chargeAmount);
        dappManager.charging(dappID, address(usdc), sizeBytes, sizeGas, chain);

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), depositAmount - chargeAmount);
    }

    function test_Charging_OnlyGov() public {
        uint256 depositAmount = 1000000;
        uint256 feePerByte = 500;
        uint256 feePerGas = 100;
        uint256 minimumDeposit = 999;
        uint256 sizeBytes = 16;
        uint256 sizeGas = 32;
        string memory chain = "ethereum";

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.stopPrank();

        vm.startPrank(user1);
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

        vm.prank(gov);
        dappManager.charging(dappID, address(usdc), sizeBytes, sizeGas, chain);
    }

    function test_Charging_Paused() public {
        uint256 sizeBytes = 16;
        uint256 sizeGas = 32;
        string memory chain = "ethereum";

        vm.startPrank(gov);
        dappManager.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        dappManager.charging(dappID, address(usdc), sizeBytes, sizeGas, chain);
    }

    function test_Charging_ZeroDAppID() public {
        uint256 sizeBytes = 16;
        uint256 sizeGas = 32;
        string memory chain = "ethereum";

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.charging(0, address(usdc), sizeBytes, sizeGas, chain);
    }

    function test_Charging_ZeroAmount() public {
        uint256 sizeByte = 0;
        uint256 sizeGas = 0;
        string memory chain = "ethereum";

        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager.charging(dappID, address(usdc), sizeByte, sizeGas, chain);
    }

    function test_Charging_InsufficientBalance() public {
        uint256 depositAmount = 1000;
        uint256 feePerByte = 500;
        uint256 feePerGas = 100;
        uint256 sizeByte = 16;
        uint256 sizeGas = 16;
        string memory chain = "ethereum";

        vm.prank(gov);
        dappManager.setFeeConfig(address(usdc), "ethereum", feePerByte, feePerGas);

        vm.startPrank(user1);
        usdc.approve(address(dappManager), depositAmount);
        dappManager.deposit(dappID, address(usdc), depositAmount);
        vm.stopPrank();

        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InsufficientBalance.selector, address(usdc))
        );
        dappManager.charging(dappID, address(usdc), sizeByte, sizeGas, chain);
    }

    // ============ SET DAPP FEE DISCOUNT TESTS ============

    function test_SetDAppFeeDiscount_ZeroDiscount() public {
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
        uint256 dappIDNew = dappManager.setDAppConfig(address(ctm), assetXMetadata);
        ctm.approve(address(dappManager), 1 ether);
        dappManager.deposit(dappIDNew, address(ctm), 1 ether);
        vm.stopPrank();

        vm.prank(gov);
        vm.expectEmit(true, false, false, true);
        emit IC3DAppManager.SetDAppFeeDiscount(dappIDNew, 0);
        dappManager.setDAppFeeDiscount(dappIDNew, 0);

        uint256 govInitialBalance = ctm.balanceOf(gov);

        vm.prank(gov);
        dappManager.charging(dappIDNew, address(ctm), sizeByte, sizeGas, "ethereum");

        uint256 govFinalBalance = ctm.balanceOf(gov);
        assertEq(govFinalBalance, govInitialBalance + totalExpectedBill);
    }

    function test_SetDAppFeeDiscount_FullDiscount() public {
        uint256 feePerByte = 100;
        uint256 feePerGas = 1 gwei;
        uint256 sizeByte = 4;
        uint256 sizeGas = 21000;

        vm.startPrank(gov);
        dappManager.setFeeConfig(address(ctm), "ethereum", feePerByte, feePerGas);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 dappIDNew = dappManager.setDAppConfig(address(ctm), assetXMetadata);
        ctm.approve(address(dappManager), 1 ether);
        dappManager.deposit(dappIDNew, address(ctm), 1 ether);
        vm.stopPrank();

        vm.prank(gov);
        dappManager.setDAppFeeDiscount(dappIDNew, 10000);

        uint256 govInitialBalance = ctm.balanceOf(gov);

        vm.prank(gov);
        dappManager.charging(dappIDNew, address(ctm), sizeByte, sizeGas, "ethereum");

        uint256 govFinalBalance = ctm.balanceOf(gov);
        assertEq(govFinalBalance, govInitialBalance);
    }

    function test_SetDAppFeeDiscount_Success() public {
        vm.prank(user1);
        uint256 dappIDNew = dappManager.setDAppConfig(address(usdc), assetXMetadata);

        vm.prank(gov);
        dappManager.setDAppFeeDiscount(dappIDNew, 10);

        (,, uint256 discount,,) = dappManager.dappConfig(dappIDNew);
        assertEq(discount, 10);
    }

    function test_SetDAppFeeDiscount_OnlyGov() public {
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        dappManager.setDAppFeeDiscount(dappID, 10);
    }

    function test_SetDAppFeeDiscount_ZeroDAppID() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.setDAppFeeDiscount(0, 10);
    }

    function test_SetDAppFeeDiscount_DiscountAboveMax() public {
        uint256 discount = 10_001;
        uint256 maxDiscount = dappManager.DISCOUNT_DENOMINATOR();
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_DiscountAboveMax.selector, discount, maxDiscount)
        );
        dappManager.setDAppFeeDiscount(dappID, discount);
    }

    // ============ VIEW FUNCTION TESTS ============

    function test_GetDAppConfig_Empty() public {
        uint256 nonExistentDAppID = 99;
        (address dappAdmin, address feeToken, uint256 discount,,) = dappManager.dappConfig(nonExistentDAppID);
        assertEq(dappAdmin, address(0));
        assertEq(feeToken, address(0));
        assertEq(discount, 0);
    }

    function test_GetDAppConfig_WithData() public {
        (address dappAdmin, address feeToken, uint256 discount,,) = dappManager.dappConfig(dappID);
        assertEq(dappAdmin, user1);
        assertEq(feeToken, address(usdc));
        assertEq(discount, 0);
    }

    function test_GetMpcAddrs_Empty() public {
        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(addrs.length, 0);
    }

    function test_GetMpcAddrs_ZeroDAppID() public {
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.getAllMpcAddrs(0);
    }

    function test_GetMpcAddrs_WithData() public {
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr2, pubKey2);

        string[] memory addrs = dappManager.getAllMpcAddrs(dappID);
        assertEq(addrs.length, 2);
        assertEq(addrs[0], mpcAddr1);
        assertEq(addrs[1], mpcAddr2);
    }

    function test_GetMpcCount_ZeroDAppID() public {
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_ZeroDAppID.selector));
        dappManager.getMpcCount(0);
    }

    function test_GetMpcPubkey_Empty() public {
        assertEq(dappManager.mpcPubkey(1, mpcAddr1), "");
    }

    function test_GetMpcPubkey_WithData() public {
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);

        assertEq(dappManager.mpcPubkey(dappID, mpcAddr1), pubKey1);
    }

    function test_GetFeeCurrency_Empty() public {
        vm.prank(gov);
        dappManager.removeFeeConfig(address(usdc));
        assertEq(dappManager.feeCurrencies(address(usdc)), false);
    }

    function test_GetFeeCurrency_WithData() public {
        assertEq(dappManager.feeCurrencies(address(usdc)), true);
    }

    function test_GetSpeChainFee_Empty() public {
        (uint256 perByte, uint256 perGas) = dappManager.specificChainFee(address(ctm), "ethereum");
        assertEq(perByte, 0);
        assertEq(perGas, 0);
    }

    function test_GetSpeChainFee_WithData() public {
        (uint256 perByte, uint256 perGas) = dappManager.specificChainFee(address(usdc), "ethereum");
        uint256 minimumDeposit = dappManager.feeMinimumDeposit(address(usdc));

        assertEq(perByte, 1);
        assertEq(perGas, 1);
        assertEq(minimumDeposit, 100);
    }

    function test_GetDAppStakePool_Empty() public {
        assertEq(dappManager.dappStakePool(1, address(usdc)), 0);
    }

    function test_GetDAppStakePool_WithData() public {
        uint256 amount = 1000;

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);
        dappManager.deposit(dappID, address(usdc), amount);
        vm.stopPrank();

        assertEq(dappManager.dappStakePool(dappID, address(usdc)), amount);
    }

    // ============ CUMULATIVE FEES TESTS ============

    function test_CumulativeFees_Empty() public {
        assertEq(dappManager.cumulativeFees(address(usdc)), 0);
    }

    function test_CumulativeFees_Success() public {
        vm.startPrank(user1);
        usdc.approve(address(dappManager), 100);
        dappManager.deposit(dappID, address(usdc), 100);
        vm.stopPrank();
        uint256 sizeBytes = 10;
        uint256 sizeGas = 10;
        (uint256 feePerByte, uint256 feePerGas) = dappManager.specificChainFee(address(usdc), "ethereum");
        uint256 expectedFees = (sizeBytes * feePerByte) + (sizeGas * feePerGas);
        vm.prank(gov);
        dappManager.charging(dappID, address(usdc), sizeBytes, sizeGas, "ethereum");
        uint256 fees = dappManager.cumulativeFees(address(usdc));
        assertEq(fees, expectedFees);
    }

    // ============ EDGE CASES ============

    function test_MultipleDApps() public {
        // Setup multiple dapps
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);
        dappManager.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        vm.prank(user2);
        uint256 dappIDNew = dappManager.setDAppConfig(address(ctm), assetXMetadata);

        // Verify they don't interfere
        (address dappAdmin1, address feeToken1,,,) = dappManager.dappConfig(dappID);
        (address dappAdmin2, address feeToken2,,,) = dappManager.dappConfig(dappIDNew);

        assertEq(dappAdmin1, user1);
        assertEq(feeToken1, address(usdc));
        assertEq(dappAdmin2, user2);
        assertEq(feeToken2, address(ctm));
    }

    function test_MultipleTokens() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(ctm), "ethereum", 1, 1);

        assertEq(dappManager.feeCurrencies(address(usdc)), true);
        assertEq(dappManager.feeCurrencies(address(ctm)), true);
    }

    function test_MultipleChains() public {
        vm.startPrank(gov);
        dappManager.setFeeConfig(address(usdc), "polygon", 1, 1);
        vm.stopPrank();

        (uint256 perByteEth, uint256 perGasEth) = dappManager.specificChainFee(address(usdc), "ethereum");
        (uint256 perBytePoly, uint256 perGasPoly) = dappManager.specificChainFee(address(usdc), "polygon");
        uint256 minimumDeposit = dappManager.feeMinimumDeposit(address(usdc));

        assertEq(perByteEth, 1);
        assertEq(perGasEth, 1);
        assertEq(perBytePoly, 1);
        assertEq(perGasPoly, 1);
        assertEq(minimumDeposit, 100);
    }

    // ============ STRESS TESTS ============

    function test_MultipleMpcAddresses() public {
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
        uint256 gasBefore = gasleft();
        vm.startPrank(user1);
        dappManager.setDAppConfig(address(usdc), assetXMetadata);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for setDAppConfig:", gasUsed);
    }

    function test_Gas_Deposit() public {
        uint256 amount = 1000;

        vm.startPrank(user1);
        usdc.approve(address(dappManager), amount);

        uint256 gasBefore = gasleft();
        dappManager.deposit(dappID, address(usdc), amount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();

        console.log("Gas used for deposit:", gasUsed);
    }

    function test_Gas_Withdraw() public {
        uint256 amount = 1000;

        vm.startPrank(user1);
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
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        dappManager.addMpcAddr(dappID, mpcAddr1, pubKey1);
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
