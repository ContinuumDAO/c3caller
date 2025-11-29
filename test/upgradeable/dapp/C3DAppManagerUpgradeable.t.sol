// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Helpers} from "../../helpers/Helpers.sol";
import {C3DAppManagerUpgradeable} from "../../../src/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {IC3DAppManager} from "../../../src/dapp/IC3DAppManager.sol";
import {MockC3CallerDAppUpgradeable} from "../../mocks/MockC3CallerDAppUpgradeable.sol";
import {C3ErrorParam} from "../../../src/utils/C3CallerUtils.sol";
import {IC3GovClient} from "../../../src/gov/IC3GovClient.sol";
import {TestERC20} from "../../mocks/TestERC20.sol";
import {C3UUIDKeeperUpgradeable} from "../../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {C3CallerUpgradeable} from "../../../src/upgradeable/C3CallerUpgradeable.sol";

contract C3DAppManagerUpgradeableTest is Helpers {
    address mpcAddr1 = 0x1234567890123456789012345678901234567890;
    string pubKey1 = "0x0987654321098765432109876543210987654321";
    address mpcAddr2 = 0x1234567890123456789012345678901234567891;
    string pubKey2 = "0x0987654321098765432109876543210987654322";
    address mpcAddr3 = 0x1234567890123456789012345678901234567892;
    string pubKey3 = "0x0987654321098765432109876543210987654323";

    string c3pingDAppKey = "v1.c3ping.c3caller_u";
    string assetXDAppKey = "v1.ctmrwa1x.assetx";
    string c3governorDAppKey = "v1.c3governor.c3caller_u";
    string maliciousDAppKey = "v1.malicious.dapp";

    string c3pingMetadata =
        "{'version':1,'name':'C3Ping','description':'Ping other networks with C3Caller','email':'admin@c3ping.com','url':'c3ping.com'}";
    string assetXMetadata =
        "{'version':1,'name':'CTMRWA1X','description':'AssetX: Cross-chain transfers','email':'admin@assetx.com','url':'assetx.org'}";
    string c3governorMetadata =
        "{'version':1,'name':'C3Governor','description':'Cross-chain governance','email':'admin@c3gov.com','url':'c3gov.com'}";
    string maliciousMetadata =
        "{'version':1,'name':'MaliciousDApp','description':'Steal your money','email':'admin@malice.com','url':'malice.com'}";

    MockC3CallerDAppUpgradeable c3ping;
    uint256 c3pingDAppID;

    MockC3CallerDAppUpgradeable assetX;
    uint256 assetXDAppID;

    MockC3CallerDAppUpgradeable c3governor;
    uint256 c3governorDAppID;

    MockC3CallerDAppUpgradeable maliciousDApp;
    uint256 maliciousDAppID;

    function setUp() public override {
        super.setUp();
        _deployC3UUIDKeeperUpgradeable(gov);
        _deployC3DAppManagerUpgradeable(gov);
        _deployC3CallerUpgradeable(gov);
        _setC3CallerUpgradeable(gov);
        _setFeeConfigUpgradeable(gov, address(usdc));
        _setFeeConfigUpgradeable(gov, address(usdc));
        _addMPCUpgradeable(gov, mpcAddr1);
        (c3ping, c3pingDAppID) = _createC3CallerDAppUpgradeable(user1, c3pingDAppKey, address(usdc), c3pingMetadata);
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        _deployC3DAppManagerUpgradeable(gov);
    }

    function test_State() public view {
        uint256 metadataLimit = dappManager_u.METADATA_LIMIT();
        uint256 dappKeyLimit = dappManager_u.DAPP_KEY_LIMIT();
        uint256 discountDenominator = dappManager_u.DISCOUNT_DENOMINATOR();
        uint256 _dappIDRegistry = dappManager_u.dappIDRegistry();
        assertEq(metadataLimit, 512);
        assertEq(dappKeyLimit, 64);
        assertEq(discountDenominator, 10_000);
        assertEq(_dappIDRegistry, 1);
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_RevertWhen_CallerNotGovOrAdmin() public {
        bytes memory onlyAuthGovOrAdminError = abi.encodeWithSelector(
            IC3DAppManager.C3DAppManager_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.GovOrAdmin
        );

        vm.expectRevert(onlyAuthGovOrAdminError);
        dappManager_u.updateDAppConfig(c3pingDAppID, user2, address(ctm), c3pingMetadata);

        vm.expectRevert(onlyAuthGovOrAdminError);
        dappManager_u.setDAppAddr(c3pingDAppID, address(c3ping), true);

        vm.expectRevert(onlyAuthGovOrAdminError);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);

        vm.expectRevert(onlyAuthGovOrAdminError);
        dappManager_u.delDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);

        vm.expectRevert(onlyAuthGovOrAdminError);
        dappManager_u.withdraw(c3pingDAppID, address(usdc));
    }

    function test_RevertWhen_CallerNotC3Caller() public {
        bytes memory onlyAuthC3CallerError = abi.encodeWithSelector(
            IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller
        );

        vm.expectRevert(onlyAuthC3CallerError);
        dappManager_u.chargePayload(c3pingDAppID, 128);

        vm.expectRevert(onlyAuthC3CallerError);
        dappManager_u.chargeGas(c3pingDAppID, 1e6 gwei);
    }

    // =============================
    // ======== DAPP STATUS ========
    // =============================

    function test_OnlyActiveDApp() public {
        vm.prank(gov);
        dappManager_u.setDAppStatus(c3pingDAppID, IC3DAppManager.DAppStatus.Suspended, "suspended dapp");

        bytes memory onlyActiveDAppError = abi.encodeWithSelector(
            IC3DAppManager.C3DAppManager_InactiveDApp.selector, c3pingDAppID, IC3DAppManager.DAppStatus.Suspended
        );

        vm.startPrank(user1);
        vm.expectRevert(onlyActiveDAppError);
        dappManager_u.setDAppAddr(c3pingDAppID, address(c3ping), true);
        vm.expectRevert(onlyActiveDAppError);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);
        vm.expectRevert(onlyActiveDAppError);
        dappManager_u.delDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);
        vm.stopPrank();

        vm.expectRevert(onlyActiveDAppError);
        dappManager_u.deposit(c3pingDAppID, address(usdc), 100);

        vm.prank(address(c3caller_u));
        vm.expectRevert(onlyActiveDAppError);
        dappManager_u.chargePayload(c3pingDAppID, 128);
    }

    function test_OnlyActiveOrDormantDApp() public {
        vm.prank(gov);
        dappManager_u.setDAppStatus(c3pingDAppID, IC3DAppManager.DAppStatus.Suspended, "suspended dapp");

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_InactiveDApp.selector, c3pingDAppID, IC3DAppManager.DAppStatus.Suspended
            )
        );
        dappManager_u.updateDAppConfig(c3pingDAppID, user2, address(ctm), c3pingMetadata);
    }

    // ================================
    // ======== DAPP EXISTENCE ========
    // ================================

    function test_RevertWhen_DAppIDNonExistent() public {
        uint256 nonExistentID = 1234567;
        bytes memory invalidDAppIDError =
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidDAppID.selector, nonExistentID);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.updateDAppConfig(nonExistentID, user2, address(ctm), c3pingMetadata);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.setDAppAddr(nonExistentID, address(c3ping), true);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.addDAppMPCAddr(nonExistentID, mpcAddr1, pubKey1);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.delDAppMPCAddr(nonExistentID, mpcAddr1, pubKey1);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.deposit(nonExistentID, address(usdc), 100);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.withdraw(nonExistentID, address(usdc));

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.chargePayload(nonExistentID, 128);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.chargeGas(nonExistentID, 1e6 gwei);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.setDAppFeeDiscount(nonExistentID, 5000);

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.setDAppStatus(nonExistentID, IC3DAppManager.DAppStatus.Active, "active dapp");

        vm.expectRevert(invalidDAppIDError);
        dappManager_u.dappStatus(nonExistentID);
    }

    // ==================================
    // ======== INIT DAPP CONFIG ========
    // ==================================

    function test_InitDAppConfig_Success() public {
        (address dappAdmin, address feeToken, uint256 discount,,) = dappManager_u.dappConfig(c3pingDAppID);
        assertEq(dappAdmin, user1);
        assertEq(feeToken, address(usdc));
        assertEq(discount, 0);
        uint256 nextDAppID = dappManager_u.deriveDAppID(user1, c3governorDAppKey);
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.InitDAppConfig(nextDAppID, c3governorDAppKey, user1, address(usdc), c3governorMetadata);
        c3governorDAppID = dappManager_u.initDAppConfig(c3governorDAppKey, address(usdc), c3governorMetadata);
        assertEq(c3governorDAppID, nextDAppID);
        (
            address _adminSet,
            address _feeTokenSet,
            uint256 _discountSet,
            uint256 _lastUpdatedSet,
            string memory _metadataSet
        ) = dappManager_u.dappConfig(c3governorDAppID);
        assertEq(_adminSet, user1);
        assertEq(_feeTokenSet, address(usdc));
        assertEq(_discountSet, 0);
        assertEq(_lastUpdatedSet, block.timestamp);
        assertEq(_metadataSet, c3governorMetadata);
    }

    function test_InitDAppConfig_RevertWhen_DAppKeyZeroLength() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.DAppKey));
        dappManager_u.initDAppConfig("", address(usdc), c3governorMetadata);
    }

    function test_InitDAppConfig_RevertWhen_DAppKeyTooLong() public {
        uint256 limit = dappManager_u.DAPP_KEY_LIMIT();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_StringTooLong.selector, 65, limit));
        dappManager_u.initDAppConfig(
            "00000000000000000000000000000000000000000000000000000000000000000", address(usdc), c3governorMetadata
        );
    }

    function test_InitDAppConfig_RevertWhen_DAppIDExists() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidDAppID.selector, c3pingDAppID));
        dappManager_u.initDAppConfig(c3pingDAppKey, address(usdc), c3governorMetadata);
    }

    function test_InitDAppConfig_RevertWhen_InvalidFeeToken() public {
        TestERC20 token = new TestERC20("Invalid token", "ABC", 18);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(token)));
        dappManager_u.initDAppConfig(c3governorDAppKey, address(token), c3governorMetadata);
    }

    function test_InitDAppConfig_RevertWhen_MetadataZeroLength() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Metadata));
        dappManager_u.initDAppConfig(c3governorDAppKey, address(usdc), "");
    }

    function test_InitDAppConfig_RevertWhen_MetadataTooLong() public {
        uint256 limit = dappManager_u.METADATA_LIMIT();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_StringTooLong.selector, 513, limit));
        dappManager_u.initDAppConfig(
            c3governorDAppKey,
            address(usdc),
            "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        );
    }

    // ====================================
    // ======== UPDATE DAPP CONFIG ========
    // ====================================

    function test_UpdateDAppConfig_Success() public {
        skip(30 days);
        (address dappAdmin, address feeToken, uint256 discount,,) = dappManager_u.dappConfig(c3pingDAppID);
        assertEq(dappAdmin, user1);
        assertEq(feeToken, address(usdc));
        assertEq(discount, 0);
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.UpdateDAppConfig(c3pingDAppID, user2, address(usdc), c3pingMetadata);
        dappManager_u.updateDAppConfig(c3pingDAppID, user2, address(usdc), c3pingMetadata);
        (
            address _adminSet,
            address _feeTokenSet,
            uint256 _discountSet,
            uint256 _lastUpdatedSet,
            string memory _metadataSet
        ) = dappManager_u.dappConfig(c3pingDAppID);
        assertEq(_adminSet, user2);
        assertEq(_feeTokenSet, address(usdc));
        assertEq(_discountSet, 0);
        assertEq(_lastUpdatedSet, block.timestamp);
        assertEq(_metadataSet, c3pingMetadata);
    }

    function test_UpdateDAppConfig_RevertWhen_DAppIDNonExistent() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidDAppID.selector, 1));
        dappManager_u.updateDAppConfig(1, user1, address(usdc), c3pingMetadata);
    }

    function test_UpdateDAppConfig_RevertWhen_BeforeCooldown() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_RecentlyUpdated.selector, c3pingDAppID));
        dappManager_u.updateDAppConfig(c3pingDAppID, user2, address(usdc), c3pingMetadata);

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.UpdateDAppConfig(c3pingDAppID, user1, address(usdc), c3pingMetadata);
        dappManager_u.updateDAppConfig(c3pingDAppID, user1, address(usdc), c3pingMetadata);
    }

    function test_UpdateDAppConfig_RevertWhen_InvalidFeeToken() public {
        skip(30 days);
        TestERC20 token = new TestERC20("Invalid token", "ABC", 18);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(token)));
        dappManager_u.updateDAppConfig(c3pingDAppID, user1, address(token), c3pingMetadata);
    }

    function test_UpdateDAppConfig_RevertWhen_MetadataZeroLength() public {
        skip(30 days);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Metadata));
        dappManager_u.updateDAppConfig(c3pingDAppID, user1, address(usdc), "");
    }

    function test_UpdateDAppConfig_RevertWhen_MetadataTooLong() public {
        skip(30 days);
        uint256 limit = dappManager_u.METADATA_LIMIT();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_StringTooLong.selector, 513, limit));
        dappManager_u.updateDAppConfig(
            c3pingDAppID,
            user1,
            address(usdc),
            "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        );
    }

    // ===============================
    // ======== SET DAPP ADDR ========
    // ===============================

    function test_SetDAppAddr_Success() public {
        TestERC20 token = new TestERC20("Test", "ABC", 18);
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.SetDAppAddr(c3pingDAppID, address(token), true);
        dappManager_u.setDAppAddr(c3pingDAppID, address(token), true);
        uint256 dappAddrID = dappManager_u.dappAddrID(address(token));
        assertEq(dappAddrID, c3pingDAppID);
        address[] memory allDAppAddrs = dappManager_u.getAllDAppAddrs(c3pingDAppID);
        assertEq(allDAppAddrs.length, 2);
        assertEq(allDAppAddrs[0], address(c3ping));
        assertEq(allDAppAddrs[1], address(token));
    }

    function test_SetDAppAddr_Removal() public {
        TestERC20 token1 = new TestERC20("Test1", "ABC", 18);
        TestERC20 token2 = new TestERC20("Test1", "ABC", 18);
        vm.startPrank(user1);
        dappManager_u.setDAppAddr(c3pingDAppID, address(token1), true);
        dappManager_u.setDAppAddr(c3pingDAppID, address(token2), true);
        dappManager_u.setDAppAddr(c3pingDAppID, address(token1), false);
        vm.stopPrank();
        uint256 dappAddrID0 = dappManager_u.dappAddrID(address(c3ping));
        uint256 dappAddrID1 = dappManager_u.dappAddrID(address(token1));
        uint256 dappAddrID2 = dappManager_u.dappAddrID(address(token2));
        assertEq(dappAddrID0, c3pingDAppID);
        assertEq(dappAddrID1, 0);
        assertEq(dappAddrID2, c3pingDAppID);
        address[] memory allDAppAddrs = dappManager_u.getAllDAppAddrs(c3pingDAppID);
        assertEq(allDAppAddrs.length, 2);
        assertEq(allDAppAddrs[0], address(c3ping));
        assertEq(allDAppAddrs[1], address(token2));
    }

    function test_SetDAppAddr_RevertWhen_InvalidAddr() public {
        vm.startPrank(user1);
        bytes memory invalidDAppAddrError =
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidDAppAddr.selector, address(c3ping));
        vm.expectRevert(invalidDAppAddrError);
        dappManager_u.setDAppAddr(c3pingDAppID, address(c3ping), true);

        dappManager_u.setDAppAddr(c3pingDAppID, address(c3ping), false);

        vm.expectRevert(invalidDAppAddrError);
        dappManager_u.setDAppAddr(c3pingDAppID, address(c3ping), false);
        vm.stopPrank();
    }

    // ===================================
    // ======== ADD DAPP MPC ADDR ========
    // ===================================

    function test_AddDAppMPCAddr_Success() public {
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.AddMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);
        string memory mpcPubkey = dappManager_u.dappMPCPubkey(c3pingDAppID, mpcAddr1);
        address dappMPCAddr0 = dappManager_u.dappMPCAddrs(c3pingDAppID, 0);
        bool isMember = dappManager_u.dappMPCMembership(c3pingDAppID, mpcAddr1);
        address[] memory allDAppMPCAddrs = dappManager_u.getAllDAppMPCAddrs(c3pingDAppID);
        assertEq(mpcPubkey, pubKey1);
        assertEq(dappMPCAddr0, mpcAddr1);
        assertTrue(isMember);
        assertEq(allDAppMPCAddrs.length, 1);
        assertEq(allDAppMPCAddrs[0], mpcAddr1);
    }

    function test_AddDAppMPCAddr_RevertWhen_IsNotValidC3CallerMPC() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidMPCAddress.selector, mpcAddr2));
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr2, pubKey2);
    }

    function test_AddDAppMPCAddr_RevertWhen_PubKeyIsLengthZero() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.PubKey));
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, "");
    }

    function test_AddDAppMPCAddr_RevertWhen_AlreadyExists() public {
        vm.startPrank(user1);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_MPCAddressExists.selector, mpcAddr1));
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey2);
        vm.stopPrank();
    }

    // ===================================
    // ======== DEL DAPP MPC ADDR ========
    // ===================================

    function test_DelDAppMPCAddr_Success() public {
        _addMPCUpgradeable(gov, mpcAddr2);
        _addMPCUpgradeable(gov, mpcAddr3);
        vm.startPrank(user1);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr2, pubKey2);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr3, pubKey3);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.DelMPCAddr(c3pingDAppID, mpcAddr2, pubKey2);
        dappManager_u.delDAppMPCAddr(c3pingDAppID, mpcAddr2, pubKey2);
        string memory mpcPubkey0 = dappManager_u.dappMPCPubkey(c3pingDAppID, mpcAddr1);
        string memory mpcPubkey1 = dappManager_u.dappMPCPubkey(c3pingDAppID, mpcAddr2);
        string memory mpcPubkey2 = dappManager_u.dappMPCPubkey(c3pingDAppID, mpcAddr3);
        address dappMPCAddr0 = dappManager_u.dappMPCAddrs(c3pingDAppID, 0);
        address dappMPCAddr1 = dappManager_u.dappMPCAddrs(c3pingDAppID, 1);
        bool isMember0 = dappManager_u.dappMPCMembership(c3pingDAppID, mpcAddr1);
        bool isMember1 = dappManager_u.dappMPCMembership(c3pingDAppID, mpcAddr2);
        bool isMember2 = dappManager_u.dappMPCMembership(c3pingDAppID, mpcAddr3);
        address[] memory allDAppMPCAddrs = dappManager_u.getAllDAppMPCAddrs(c3pingDAppID);
        assertEq(mpcPubkey0, pubKey1);
        assertEq(mpcPubkey1, "");
        assertEq(mpcPubkey2, pubKey3);
        assertEq(dappMPCAddr0, mpcAddr1);
        assertEq(dappMPCAddr1, mpcAddr3);
        assertTrue(isMember0);
        assertFalse(isMember1);
        assertTrue(isMember2);
        assertEq(allDAppMPCAddrs.length, 2);
        assertEq(allDAppMPCAddrs[0], mpcAddr1);
        assertEq(allDAppMPCAddrs[1], mpcAddr3);
    }

    function test_DelDAppMPCAddr_RevertWhen_PubKeyIsLengthZero() public {
        vm.startPrank(user1);
        dappManager_u.addDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.PubKey));
        dappManager_u.delDAppMPCAddr(c3pingDAppID, mpcAddr1, "");
        vm.stopPrank();
    }

    function test_DelDAppMPCAddr_RevertWhen_DoesNotExist() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_MPCAddressNotFound.selector, mpcAddr1));
        dappManager_u.delDAppMPCAddr(c3pingDAppID, mpcAddr1, pubKey2);
    }

    // =========================
    // ======== DEPOSIT ========
    // =========================

    function test_Deposit_Success() public {
        uint256 senderBalInitial = usdc.balanceOf(user1);
        uint256 contractBalInitial = usdc.balanceOf(address(dappManager_u));
        uint256 initialPool = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 depositAmount = 10 * 10 ** usdc.decimals();
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.Deposit(c3pingDAppID, address(usdc), depositAmount, initialPool + depositAmount);
        dappManager_u.deposit(c3pingDAppID, address(usdc), depositAmount);
        uint256 senderBalFinal = usdc.balanceOf(user1);
        uint256 contractBalFinal = usdc.balanceOf(address(dappManager_u));
        assertEq(senderBalFinal, senderBalInitial - depositAmount);
        assertEq(contractBalFinal, contractBalInitial + depositAmount);
    }

    function test_Deposit_RevertWhen_InvalidFeeToken() public {
        TestERC20 token = new TestERC20("Invalid token", "ABC", 18);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(token)));
        dappManager_u.deposit(c3pingDAppID, address(token), 100);
    }

    function test_Deposit_RevertWhen_BelowMinimumDeposit() public {
        uint256 minimumDeposit = 10 * 10 ** usdc.decimals();
        vm.prank(gov);
        dappManager_u.setFeeMinimumDeposit(address(usdc), minimumDeposit);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_BelowMinimumDeposit.selector, minimumDeposit - 1, minimumDeposit
            )
        );
        dappManager_u.deposit(c3pingDAppID, address(usdc), minimumDeposit - 1);
    }

    function test_Deposit_RevertWhen_InsufficientBalance() public {
        uint256 bal = usdc.balanceOf(user1);
        vm.prank(user1);
        usdc.transfer(user2, bal);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user1, 0, 10));
        dappManager_u.deposit(c3pingDAppID, address(usdc), 10);
    }

    // ==========================
    // ======== WITHDRAW ========
    // ==========================

    function test_Withdraw_Success() public {
        uint256 minimumDepositUSDC = 10 * 10 ** usdc.decimals();
        vm.prank(gov);
        dappManager_u.setFeeMinimumDeposit(address(usdc), minimumDepositUSDC);
        uint256 expectedWithdrawal = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 adminBalInitial = usdc.balanceOf(user1);
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.Withdraw(c3pingDAppID, address(usdc), expectedWithdrawal - minimumDepositUSDC);
        dappManager_u.withdraw(c3pingDAppID, address(usdc));
        uint256 poolAfterWithdrawal = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 adminBalFinal = usdc.balanceOf(user1);
        assertEq(poolAfterWithdrawal, minimumDepositUSDC);
        assertEq(adminBalFinal, adminBalInitial + (expectedWithdrawal - minimumDepositUSDC));
    }

    function test_Withdraw_RevertWhen_AmountMoreThanMinimumDeposit() public {
        uint256 minimumDepositUSDC = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        vm.prank(gov);
        dappManager_u.setFeeMinimumDeposit(address(usdc), minimumDepositUSDC + 1);
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_BelowMinimumDeposit.selector, minimumDepositUSDC, minimumDepositUSDC + 1
            )
        );
        dappManager_u.withdraw(c3pingDAppID, address(usdc));
    }

    function test_Withdraw_RevertWhen_AmountIsZero() public {
        uint256 minimumDepositUSDC = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        vm.prank(gov);
        dappManager_u.setFeeMinimumDeposit(address(usdc), minimumDepositUSDC);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager_u.withdraw(c3pingDAppID, address(usdc));
    }

    // ================================
    // ======== CHARGE PAYLOAD ========
    // ================================

    function test_ChargePayload_Success_ZeroDiscount() public {
        uint256 balDAppInitial = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 cumulativeFeesInitial = dappManager_u.cumulativeFees(address(usdc));
        uint256 payloadSize = 128;
        uint256 bill = payloadSize * dappManager_u.payloadPerByteFee(address(usdc));
        uint256 discount = 0;
        uint256 remaining = balDAppInitial - bill;
        vm.prank(address(c3caller_u));
        emit IC3DAppManager.ChargePayload(c3pingDAppID, address(usdc), bill, discount, remaining);
        dappManager_u.chargePayload(c3pingDAppID, payloadSize);
        uint256 balDAppFinal = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 cumulativeFeesFinal = dappManager_u.cumulativeFees(address(usdc));
        assertEq(balDAppFinal, remaining);
        assertEq(cumulativeFeesFinal, cumulativeFeesInitial + bill);
    }

    function test_ChargePayload_Success_HalfDiscount() public {
        uint256 discountNumerator = 5000;
        vm.prank(gov);
        dappManager_u.setDAppFeeDiscount(c3pingDAppID, discountNumerator);
        uint256 balDAppInitial = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 cumulativeFeesInitial = dappManager_u.cumulativeFees(address(usdc));
        uint256 payloadSize = 128;
        uint256 bill = payloadSize * dappManager_u.payloadPerByteFee(address(usdc));
        uint256 discount = bill * discountNumerator / 10_000;
        uint256 remaining = balDAppInitial - bill + discount;
        vm.prank(address(c3caller_u));
        emit IC3DAppManager.ChargePayload(c3pingDAppID, address(usdc), bill, discount, remaining);
        dappManager_u.chargePayload(c3pingDAppID, payloadSize);
        uint256 balDAppFinal = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 cumulativeFeesFinal = dappManager_u.cumulativeFees(address(usdc));
        assertEq(balDAppFinal, remaining);
        assertEq(cumulativeFeesFinal, cumulativeFeesInitial + (bill - discount));
    }

    function test_ChargePayload_Success_FullDiscount() public {
        uint256 discountNumerator = 10_000;
        vm.prank(gov);
        dappManager_u.setDAppFeeDiscount(c3pingDAppID, discountNumerator);
        uint256 balDAppInitial = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 payloadSize = 128;
        uint256 bill = payloadSize * dappManager_u.payloadPerByteFee(address(usdc));
        uint256 discount = bill * discountNumerator / 10_000;
        uint256 remaining = balDAppInitial - bill + discount;
        vm.prank(address(c3caller_u));
        emit IC3DAppManager.ChargePayload(c3pingDAppID, address(usdc), bill, discount, remaining);
        dappManager_u.chargePayload(c3pingDAppID, payloadSize);
        uint256 balDAppFinal = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 cumulativeFeesFinal = dappManager_u.cumulativeFees(address(usdc));
        assertEq(balDAppFinal, remaining);
        assertEq(cumulativeFeesFinal, 0);
    }

    function test_ChargePayload_RevertWhen_BillIsZero() public {
        vm.prank(address(c3caller_u));
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager_u.chargePayload(c3pingDAppID, 0);
    }

    function test_ChargePayload_RevertWhen_InsufficientBalance() public {
        uint256 poolBalance = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 payloadSize = 10_001;
        uint256 bill = payloadSize * dappManager_u.payloadPerByteFee(address(usdc));
        vm.prank(address(c3caller_u));
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InsufficientBalance.selector, poolBalance, bill)
        );
        dappManager_u.chargePayload(c3pingDAppID, payloadSize);
    }

    // ============================
    // ======== CHARGE GAS ========
    // ============================

    function test_ChargeGas_Success() public {
        uint256 balDAppInitial = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 cumulativeFeesInitial = dappManager_u.cumulativeFees(address(usdc));
        uint256 gasSize = 1e6 gwei;
        uint256 bill = gasSize * dappManager_u.gasPerEtherFee(address(usdc)) / 1 ether;
        uint256 remaining = balDAppInitial - bill;
        vm.prank(address(c3caller_u));
        emit IC3DAppManager.ChargeGas(c3pingDAppID, address(usdc), bill, remaining);
        dappManager_u.chargeGas(c3pingDAppID, gasSize);
        uint256 balDAppFinal = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 cumulativeFeesFinal = dappManager_u.cumulativeFees(address(usdc));
        assertEq(balDAppFinal, remaining);
        assertEq(cumulativeFeesFinal, cumulativeFeesInitial + bill);
    }

    function test_ChargeGas_RevertWhen_BillIsZero() public {
        vm.prank(address(c3caller_u));
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager_u.chargeGas(c3pingDAppID, 0);
    }

    function test_ChargeGas_RevertWhen_InsufficientBalance() public {
        uint256 poolBalance = dappManager_u.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasSize = 0.1 ether;
        uint256 bill = gasSize * dappManager_u.gasPerEtherFee(address(usdc)) / 1 ether;
        vm.prank(address(c3caller_u));
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InsufficientBalance.selector, poolBalance, bill)
        );
        dappManager_u.chargeGas(c3pingDAppID, gasSize);
    }

    // =========================
    // ======== COLLECT ========
    // =========================

    function test_Collect_Success() public {
        uint256 expectedTotalFee = 128 * dappManager_u.payloadPerByteFee(address(usdc));
        uint256 balGovInitial = usdc.balanceOf(gov);
        uint256 balContractInitial = usdc.balanceOf(address(dappManager_u));
        vm.prank(address(c3caller_u));
        dappManager_u.chargePayload(c3pingDAppID, 128);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.Collect(address(usdc), expectedTotalFee);
        dappManager_u.collect(address(usdc));
        uint256 balGovFinal = usdc.balanceOf(gov);
        uint256 balContractFinal = usdc.balanceOf(address(dappManager_u));
        assertEq(balGovFinal, balGovInitial + expectedTotalFee);
        assertEq(balContractFinal, balContractInitial - expectedTotalFee);
    }

    function test_Collect_RevertWhen_NoFees() public {
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.Fee));
        dappManager_u.collect(address(usdc));
    }

    // ================================
    // ======== SET FEE CONFIG ========
    // ================================

    function test_SetFeeConfig_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.SetFeeConfig(address(usdc), 97, 62);
        dappManager_u.setFeeConfig(address(usdc), 97, 62);
        assertTrue(dappManager_u.feeCurrencies(address(usdc)));
        assertEq(dappManager_u.payloadPerByteFee(address(usdc)), 97);
        assertEq(dappManager_u.gasPerEtherFee(address(usdc)), 62);
    }

    function test_SetFeeConfig_RevertWhen_FeeTokenIsZeroAddress() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZeroAddress.selector, C3ErrorParam.Token));
        dappManager_u.setFeeConfig(address(0), 1, 2);
    }

    function test_SetFeeConfig_RevertWhen_PayloadFeeIsZero() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.PerByteFee));
        dappManager_u.setFeeConfig(address(usdc), 0, 3);
    }

    function test_SetFeeConfig_RevertWhen_GasFeeIsZero() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.PerGasFee));
        dappManager_u.setFeeConfig(address(usdc), 3, 0);
    }

    // =========================================
    // ======== SET FEE MINIMUM DEPOSIT ========
    // =========================================

    function test_SetFeeMinimumDeposit_Success() public {
        uint256 minDeposit = 10 * 10 ** usdc.decimals();
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.SetFeeMinimumDeposit(address(usdc), minDeposit);
        dappManager_u.setFeeMinimumDeposit(address(usdc), minDeposit);
        assertEq(dappManager_u.feeMinimumDeposit(address(usdc)), minDeposit);
    }

    function test_SetFeeMinimumDeposit_RevertWhen_MinIsZero() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_IsZero.selector, C3ErrorParam.MinimumDeposit)
        );
        dappManager_u.setFeeMinimumDeposit(address(usdc), 0);
    }

    function test_SetFeeMinimumDeposit_RevertWhen_InvalidFeeToken() public {
        TestERC20 randomToken = new TestERC20("Random token", "ABC", 18);
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidFeeToken.selector, address(randomToken))
        );
        dappManager_u.setFeeMinimumDeposit(address(randomToken), 1050);
    }

    // ===================================
    // ======== REMOVE FEE CONFIG ========
    // ===================================

    function test_RemoveFeeConfig_Success() public {
        uint256 _gasPerEtherFee = dappManager_u.gasPerEtherFee(address(usdc));
        vm.prank(gov);
        dappManager_u.removeFeeConfig(address(usdc));
        assertFalse(dappManager_u.feeCurrencies(address(usdc)));
        assertEq(dappManager_u.feeMinimumDeposit(address(usdc)), 0);
        assertEq(dappManager_u.payloadPerByteFee(address(usdc)), 0);
        assertEq(dappManager_u.gasPerEtherFee(address(usdc)), _gasPerEtherFee);
    }

    // =======================================
    // ======== SET DAPP FEE DISCOUNT ========
    // =======================================

    function test_SetDAppFeeDiscount_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.SetDAppFeeDiscount(c3pingDAppID, 5000);
        dappManager_u.setDAppFeeDiscount(c3pingDAppID, 5000);
        (,, uint256 discount,,) = dappManager_u.dappConfig(c3pingDAppID);
        assertEq(discount, 5000);
    }

    function test_SetDAppFeeDiscount_RevertWhen_DiscountIsAboveMax() public {
        uint256 maxDiscountDenominator = dappManager_u.DISCOUNT_DENOMINATOR();
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3DAppManager.C3DAppManager_DiscountAboveMax.selector, 10_001, maxDiscountDenominator
            )
        );
        dappManager_u.setDAppFeeDiscount(c3pingDAppID, 10_001);
    }

    // =================================
    // ======== SET DAPP STATUS ========
    // =================================

    function test_SetDAppStatus_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3DAppManager.DAppStatusChanged(
            c3pingDAppID, IC3DAppManager.DAppStatus.Active, IC3DAppManager.DAppStatus.Suspended, "suspended dapp"
        );
        dappManager_u.setDAppStatus(c3pingDAppID, IC3DAppManager.DAppStatus.Suspended, "suspended dapp");
    }

    function test_SetDAppStatus_RevertWhen_InvalidStatusTransition() public {
        IC3DAppManager.DAppStatus active = IC3DAppManager.DAppStatus.Active;
        IC3DAppManager.DAppStatus dormant = IC3DAppManager.DAppStatus.Dormant;
        IC3DAppManager.DAppStatus suspended = IC3DAppManager.DAppStatus.Suspended;
        IC3DAppManager.DAppStatus deprecated = IC3DAppManager.DAppStatus.Deprecated;

        // DApp is active by default
        IC3DAppManager.DAppStatus currentStatus = dappManager_u.dappStatus(c3pingDAppID);
        assertEq(uint8(currentStatus), uint8(active));
        assertEq(dappManager_u.statusReason(c3pingDAppID), "");

        // Make fee token deprecated, validate new one
        vm.startPrank(gov);
        dappManager_u.removeFeeConfig(address(usdc));
        dappManager_u.setFeeConfig(address(ctm), 1, 1);
        dappManager_u.setFeeMinimumDeposit(address(ctm), 100);
        vm.stopPrank();

        bool usdcValid = dappManager_u.feeCurrencies(address(usdc));
        assertFalse(usdcValid);

        // DApp is using deprecated fee token, dormant
        currentStatus = dappManager_u.dappStatus(c3pingDAppID);
        assertEq(uint8(currentStatus), uint8(dormant));
        assertEq(dappManager_u.statusReason(c3pingDAppID), "");

        // DApp upgrades their fee token to validated one, active
        skip(30 days);
        vm.prank(user1);
        dappManager_u.updateDAppConfig(c3pingDAppID, user1, address(ctm), c3pingMetadata);
        currentStatus = dappManager_u.dappStatus(c3pingDAppID);
        assertEq(uint8(currentStatus), uint8(active));
        assertEq(dappManager_u.statusReason(c3pingDAppID), "");

        // DApp status set to suspended
        vm.prank(gov);
        dappManager_u.setDAppStatus(c3pingDAppID, suspended, "bad dapp");
        currentStatus = dappManager_u.dappStatus(c3pingDAppID);
        assertEq(uint8(currentStatus), uint8(suspended));
        assertEq(dappManager_u.statusReason(c3pingDAppID), "bad dapp");

        // DApp status set to deprecated
        vm.prank(gov);
        dappManager_u.setDAppStatus(c3pingDAppID, deprecated, "dead dapp");
        currentStatus = dappManager_u.dappStatus(c3pingDAppID);
        assertEq(uint8(currentStatus), uint8(deprecated));
        assertEq(dappManager_u.statusReason(c3pingDAppID), "dead dapp");

        // DApp status cannot be changed once deprecated
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(IC3DAppManager.C3DAppManager_InvalidStatusTransition.selector, deprecated, active)
        );
        dappManager_u.setDAppStatus(c3pingDAppID, active, "reuse dapp");
    }
}
