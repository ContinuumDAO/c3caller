// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Helpers} from "../../helpers/Helpers.sol";
import {MockC3CallerDApp} from "../../mocks/MockC3CallerDApp.sol";
import {IC3CallerDApp} from "../../../src/dapp/IC3CallerDApp.sol";
import {C3ErrorParam} from "../../../src/utils/C3CallerUtils.sol";
import {IC3Caller} from "../../../src/IC3Caller.sol";
import {C3UUIDKeeperUpgradeable} from "../../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {C3DAppManagerUpgradeable} from "../../../src/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {C3CallerUpgradeable} from "../../../src/upgradeable/C3CallerUpgradeable.sol";

contract C3CallerDAppUpgradeableTest is Helpers {
    using Strings for address;

    MockC3CallerDApp mockC3CallerDApp;
    uint256 mockC3CallerDAppID;
    string mockDAppKey = "v1.mockdapp.c3caller_u";
    string mockMetadata = "{'version':1,'name':'MockC3CallerDApp','description':'Mock C3CallerDApp','email':'admin@mock.com','url':'mock.com'}";

    function setUp() public override virtual {
        super.setUp();
        _deployC3UUIDKeeperUpgradeable(gov);
        _deployC3DAppManagerUpgradeable(gov);
        _deployC3CallerUpgradeable(gov);
        _setC3CallerUpgradeable(gov);
        _setFeeConfigUpgradeable(gov, address(usdc));
        mockC3CallerDAppID = _initDAppConfigUpgradeable(gov, mockDAppKey, address(usdc), mockMetadata);
        mockC3CallerDApp = new MockC3CallerDApp(address(c3caller_u), mockC3CallerDAppID);

        vm.startPrank(gov);
        usdc.approve(address(dappManager_u), type(uint256).max);
        dappManager_u.deposit(mockC3CallerDAppID, address(usdc), 100 * 10 ** usdc.decimals());
        dappManager_u.setDAppAddr(mockC3CallerDAppID, address(mockC3CallerDApp), true);
        vm.stopPrank();

        _activateChainIDUpgradeable(gov, "ethereum");
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        mockC3CallerDApp = new MockC3CallerDApp(address(c3caller_u), mockC3CallerDAppID);
    }

    function test_State() public view {
        uint256 _mockC3CallerDAppID = mockC3CallerDApp.dappID();
        address _c3caller = mockC3CallerDApp.c3caller();
        assertEq(_mockC3CallerDAppID, mockC3CallerDAppID);
        assertEq(_c3caller, address(c3caller_u));
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_RevertWhen_CallerNotC3Caller() public {
        string memory message = "Incoming message";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, message);
        bytes memory reason = abi.encodeWithSelector(MockC3CallerDApp.TargetCallFailed.selector);
        vm.expectRevert(abi.encodeWithSelector(IC3CallerDApp.C3CallerDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller));
        mockC3CallerDApp.c3Fallback(mockC3CallerDAppID, data, reason);
    }

    // ============================
    // ======== C3FALLBACK ========
    // ============================

    function test_C3Fallback_Success() public {
        string memory message = "Incoming message";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, message);
        bytes memory reason = abi.encodeWithSelector(MockC3CallerDApp.TargetCallFailed.selector);
        vm.prank(address(c3caller_u));
        bool success = mockC3CallerDApp.c3Fallback(mockC3CallerDAppID, data, reason);
        bytes memory _reason = mockC3CallerDApp.reason();
        string memory _message = mockC3CallerDApp.fallbackMessage();
        assertTrue(success);
        assertEq(_reason, reason);
        assertEq(_message, message);
    }

    function test_C3Fallback_InvalidDAppID() public {
        string memory message = "Incoming message";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, message);
        bytes memory reason = abi.encodeWithSelector(MockC3CallerDApp.TargetCallFailed.selector);
        uint256 wrongDAppID = 79;
        vm.prank(address(c3caller_u));
        vm.expectRevert(abi.encodeWithSelector(IC3CallerDApp.C3CallerDApp_InvalidDAppID.selector, mockC3CallerDAppID, wrongDAppID));
        mockC3CallerDApp.c3Fallback(wrongDAppID, data, reason);
    }

    function test_C3Fallback_DataLessThan4Bytes() public {
        bytes memory data = bytes("");
        bytes memory reason =  abi.encodeWithSelector(MockC3CallerDApp.TargetCallFailed.selector);
        vm.prank(address(c3caller_u));
        bool success = mockC3CallerDApp.c3Fallback(mockC3CallerDAppID, data, reason);
        bytes memory _reason = mockC3CallerDApp.reason();
        bytes4 _selector = mockC3CallerDApp.selector();
        assertFalse(success);
        assertEq(_reason, reason);
        assertEq(abi.encode(_selector), abi.encode(0));
    }

    // ========================
    // ======== C3CALL ========
    // ========================

    function test_C3Call_Success() public {
        address to = address(mockC3CallerDApp);
        string memory toChainID = "ethereum";
        string memory message = "Outgoing message";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, message);
        bytes32 uuid = uuidKeeper_u.calcCallerUUID(address(c3caller_u), mockC3CallerDAppID, to.toHexString(), toChainID, data);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogC3Call(mockC3CallerDAppID, uuid, address(mockC3CallerDApp), toChainID, to.toHexString(), data, "");
        mockC3CallerDApp.mockC3Call(to, toChainID, message);
    }

    // ===================================
    // ======== C3CALL WITH EXTRA ========
    // ===================================

    function test_C3CallWithExtra_Success() public {
        address to = address(mockC3CallerDApp);
        string memory toChainID = "ethereum";
        string memory message = "Outgoing message";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, message);
        bytes32 uuid = uuidKeeper_u.calcCallerUUID(address(c3caller_u), mockC3CallerDAppID, to.toHexString(), toChainID, data);
        string memory extra = "extra data to include in event";
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogC3Call(mockC3CallerDAppID, uuid, address(mockC3CallerDApp), toChainID, to.toHexString(), data, bytes(extra));
        mockC3CallerDApp.mockC3CallWithExtra(to, toChainID, message, extra);
    }

    // =============================
    // ======== C3BROADCAST ========
    // =============================

    function test_C3Broadcast_Success() public {
        _activateChainIDUpgradeable(gov, "polygon");
        _activateChainIDUpgradeable(gov, "avalanche");
        address[] memory targets = new address[](3);
        targets[0] = address(mockC3CallerDApp);
        targets[1] = address(mockC3CallerDApp);
        targets[2] = address(mockC3CallerDApp);
        string[] memory toChainIDs = new string[](3);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        toChainIDs[2] = "avalanche";
        string memory outgoingMessage = "C3Broadcast";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, outgoingMessage);
        for (uint256 i = 0; i < 3; i++) {
            bytes32 uuid = uuidKeeper_u.calcCallerUUIDWithNonce(
                address(c3caller_u),
                mockC3CallerDAppID,
                targets[i].toHexString(),
                toChainIDs[i],
                data,
                uuidKeeper_u.currentNonce() + i + 1
            );
            vm.expectEmit(true, true, true, true);
            emit IC3Caller.LogC3Call(
                mockC3CallerDAppID, uuid, address(mockC3CallerDApp), toChainIDs[i], targets[i].toHexString(), data, ""
            );
        }
        mockC3CallerDApp.mockC3Broadcast(targets, toChainIDs, outgoingMessage);
    }
}
