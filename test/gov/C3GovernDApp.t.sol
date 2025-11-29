// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Helpers} from "../helpers/Helpers.sol";
import {MockC3GovernDApp} from "../mocks/MockC3GovernDApp.sol";
import {C3GovernDApp} from "../../src/gov/C3GovernDApp.sol";
import {IC3GovernDApp} from "../../src/gov/IC3GovernDApp.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";
import {IC3Caller} from "../../src/IC3Caller.sol";

contract C3GovernDAppTest is Helpers {
    using Strings for address;

    MockC3GovernDApp mockC3GovernDApp;
    uint256 mockC3GovernDAppID;
    string mockDAppKey = "v1.mockdapp.c3caller";
    string mockMetadata =
        "{'version':1,'name':'MockC3GovernDApp','description':'Mock C3GovernDApp','email':'admin@mock.com','url':'mock.com'}";

    function setUp() public virtual override {
        super.setUp();
        _deployC3UUIDKeeper(gov);
        _deployC3DAppManager(gov);
        _deployC3Caller(gov);
        _setC3Caller(gov);
        _setFeeConfig(gov, address(usdc));
        mockC3GovernDAppID = _initDAppConfig(gov, mockDAppKey, address(usdc), mockMetadata);
        mockC3GovernDApp = new MockC3GovernDApp(gov, address(c3caller), mockC3GovernDAppID);

        vm.startPrank(gov);
        usdc.approve(address(dappManager), type(uint256).max);
        dappManager.deposit(mockC3GovernDAppID, address(usdc), 100 * 10 ** usdc.decimals());
        dappManager.setDAppAddr(mockC3GovernDAppID, address(mockC3GovernDApp), true);
        vm.stopPrank();

        _activateChainID(gov, "ethereum");
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        mockC3GovernDApp = new MockC3GovernDApp(gov, address(c3caller), mockC3GovernDAppID);
    }

    function test_State() public view {
        uint256 _delay = mockC3GovernDApp.delay();
        address _gov = mockC3GovernDApp.gov();
        assertEq(_delay, 2 days);
        assertEq(_gov, gov);
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_RevertWhen_CallerNotGov() public {
        string memory targetStr = address(mockC3GovernDApp).toHexString();
        string memory toChainID = "ethereum";
        bytes memory data = abi.encodeWithSelector(MockC3GovernDApp.mockC3Executable.selector, "Incoming message");
        string[] memory targetStrs = new string[](3);
        targetStrs[0] = targetStr;
        targetStrs[1] = targetStr;
        targetStrs[2] = targetStr;
        string[] memory toChainIDs = new string[](3);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        toChainIDs[2] = "arbitrum";
        bytes memory onlyAuthGovError = abi.encodeWithSelector(
            IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
        );

        vm.expectRevert(onlyAuthGovError);
        mockC3GovernDApp.changeGov(user1);

        vm.expectRevert(onlyAuthGovError);
        mockC3GovernDApp.doGov(targetStr, toChainID, data);

        vm.expectRevert(onlyAuthGovError);
        mockC3GovernDApp.doGovBroadcast(targetStrs, toChainIDs, data);

        vm.expectRevert(onlyAuthGovError);
        mockC3GovernDApp.setDelay(3 days);
    }

    // ============================
    // ======== CHANGE GOV ========
    // ============================

    function test_ChangeGov_Success() public {
        uint256 newGovExpectedEffectiveTime = block.timestamp + mockC3GovernDApp.delay();
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3GovernDApp.LogChangeGov(gov, user1, newGovExpectedEffectiveTime);
        mockC3GovernDApp.changeGov(user1);
        assertEq(mockC3GovernDApp.gov(), gov);
        vm.warp(newGovExpectedEffectiveTime);
        assertEq(mockC3GovernDApp.gov(), user1);
    }

    function test_ChangeGov_RevertWhen_ZeroAddress() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(IC3GovernDApp.C3GovernDApp_IsZeroAddress.selector, C3ErrorParam.Gov));
        mockC3GovernDApp.changeGov(address(0));
    }

    // ========================
    // ======== DO GOV ========
    // ========================

    function test_DoGov_Success() public {
        string memory target = address(mockC3GovernDApp).toHexString();
        string memory toChainID = "ethereum";
        string memory message = "Outgoing message";
        bytes memory data = abi.encodeWithSelector(MockC3GovernDApp.mockC3Executable.selector, message);
        bytes32 uuid = uuidKeeper.calcCallerUUID(address(c3caller), mockC3GovernDAppID, target, toChainID, data);
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogC3Call(mockC3GovernDAppID, uuid, address(mockC3GovernDApp), toChainID, target, data, "");
        bytes32 _uuid = mockC3GovernDApp.doGov(target, toChainID, data);
        assertEq(_uuid, uuid);
    }

    // ==================================
    // ======== DO GOV BROADCAST ========
    // ==================================

    function test_DoGovBroadcast_Success() public {
        _activateChainID(gov, "polygon");
        _activateChainID(gov, "avalanche");
        address[] memory targets = new address[](3);
        targets[0] = address(mockC3GovernDApp);
        targets[1] = address(mockC3GovernDApp);
        targets[2] = address(mockC3GovernDApp);
        string[] memory toChainIDs = new string[](3);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        toChainIDs[2] = "avalanche";
        string memory outgoingMessage = "C3Broadcast";
        bytes memory data = abi.encodeWithSelector(MockC3GovernDApp.mockC3Executable.selector, outgoingMessage);
        bytes32[] memory uuids = new bytes32[](3);
        vm.prank(gov);
        for (uint256 i = 0; i < 3; i++) {
            bytes32 uuid = uuidKeeper.calcCallerUUIDWithNonce(
                address(c3caller),
                mockC3GovernDAppID,
                targets[i].toHexString(),
                toChainIDs[i],
                data,
                uuidKeeper.currentNonce() + i + 1
            );
            uuids[i] = uuid;
            vm.expectEmit(true, true, true, true);
            emit IC3Caller.LogC3Call(
                mockC3GovernDAppID, uuid, address(mockC3GovernDApp), toChainIDs[i], targets[i].toHexString(), data, ""
            );
        }
        bytes32[] memory _uuids = mockC3GovernDApp.mockC3Broadcast(targets, toChainIDs, outgoingMessage);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(_uuids[i], uuids[i]);
        }
    }

    // ===========================
    // ======== SET DELAY ========
    // ===========================

    function test_SetDelay_Success() public {
        vm.prank(gov);
        mockC3GovernDApp.setDelay(3 days);
        assertEq(mockC3GovernDApp.delay(), 3 days);
    }
}
