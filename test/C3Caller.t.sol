// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Helpers} from "./helpers/Helpers.sol";
import {IC3GovClient} from "../src/gov/IC3GovClient.sol";
import {C3UUIDKeeper} from "../src/uuid/C3UUIDKeeper.sol";
import {C3DAppManager} from "../src/dapp/C3DAppManager.sol";
import {IC3DAppManager} from "../src/dapp/IC3DAppManager.sol";
import {IC3CallerDApp} from "../src/dapp/IC3CallerDApp.sol";
import {C3Caller} from "../src/C3Caller.sol";
import {IC3Caller} from "../src/IC3Caller.sol";
import {C3ErrorParam} from "../src/utils/C3CallerUtils.sol";
import {MockC3CallerDApp} from "./mocks/MockC3CallerDApp.sol";

contract C3CallerTest is Helpers {
    using Strings for address;

    MockC3CallerDApp c3ping;
    uint256 c3pingDAppID;
    string c3pingDAppKey = "v1.c3ping.c3caller";
    string c3pingMetadata =
        "{'version':1,'name':'C3Ping','description':'Ping other networks with C3Caller','email':'admin@c3ping.com','url':'c3ping.com'}";

    MockC3CallerDApp c3governor;
    uint256 c3governorDAppID;
    string c3governorDAppKey = "v1.c3governor.c3caller";
    string c3governorMetadata =
        "{'version':1,'name':'C3Governor','description':'Cross-chain governance','email':'admin@c3gov.com','url':'c3gov.com'}";

    function setUp() public virtual override {
        super.setUp();
        _deployC3UUIDKeeper(gov);
        _deployC3DAppManager(gov);
        _deployC3Caller(gov);
        _setC3Caller(gov);
        _setFeeConfig(gov, address(usdc));
        _setFeeConfig(gov, address(ctm));
        vm.prank(user1);
        usdc.approve(address(dappManager), type(uint256).max);
        vm.prank(user2);
        ctm.approve(address(dappManager), type(uint256).max);
        (c3ping, c3pingDAppID) = _createC3CallerDApp(user1, c3pingDAppKey, address(usdc), c3pingMetadata);
        (c3governor, c3governorDAppID) = _createC3CallerDApp(user2, c3governorDAppKey, address(ctm), c3governorMetadata);
    }

    function _addMPC(address _mpc) internal {
        vm.prank(gov);
        c3caller.addMPC(_mpc);
    }

    function _setGasPrice(uint256 _gasPrice) internal returns (uint256) {
        vm.txGasPrice(_gasPrice);
        return _gasPrice;
    }

    function _getMockC3EvmMessage() internal view returns (IC3Caller.C3EvmMessage memory) {
        bytes32 uuid = keccak256("uuid");
        address target = address(c3ping);
        string memory fromChainID = "ethereum";
        string memory sourceTx = "source chain tx hash";
        string memory fallbackTo = address(c3ping).toHexString();
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, "Incoming message");
        return IC3Caller.C3EvmMessage(uuid, target, fromChainID, sourceTx, fallbackTo, data);
    }

    function _getMockC3EvmMessageRevert() internal view returns (IC3Caller.C3EvmMessage memory) {
        bytes32 uuid = keccak256("uuid");
        address target = address(c3ping);
        string memory fromChainID = "ethereum";
        string memory sourceTx = "source chain tx hash";
        string memory fallbackTo = address(c3ping).toHexString();
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3ExecutableRevert.selector);
        return IC3Caller.C3EvmMessage(uuid, target, fromChainID, sourceTx, fallbackTo, data);
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public {
        c3caller = new C3Caller(address(uuidKeeper), address(dappManager));
    }

    function test_State() public view {
        address _uuidKeeper = c3caller.uuidKeeper();
        address _dappManager = c3caller.dappManager();
        assertEq(_uuidKeeper, address(uuidKeeper));
        assertEq(_dappManager, address(dappManager));
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_RevertWhen_CallerNotGov() public {
        bytes memory onlyAuthGovError = abi.encodeWithSelector(
            IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
        );

        vm.expectRevert(onlyAuthGovError);
        c3caller.addMPC(mpc1);

        vm.expectRevert(onlyAuthGovError);
        c3caller.revokeMPC(mpc1);

        vm.expectRevert(onlyAuthGovError);
        c3caller.activateChainID("arbitrum");

        vm.expectRevert(onlyAuthGovError);
        c3caller.deactivateChainID("arbitrum");
    }

    function test_RevertWhen_CallerNotMPC() public {
        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage(
            keccak256("uuid"), treasury, "ethereum", "sourceTx", address(c3ping).toHexString(), ""
        );
        bytes memory onlyAuthMPCError = abi.encodeWithSelector(
            IC3GovClient.C3GovClient_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.MPC
        );

        vm.expectRevert(onlyAuthMPCError);
        c3caller.execute(c3pingDAppID, message);

        vm.expectRevert(onlyAuthMPCError);
        c3caller.c3Fallback(c3pingDAppID, message);
    }

    // ==============================
    // ======== ADD CHAIN ID ========
    // ==============================

    string arbitrum = "arbitrum";

    function test_AddChainID_State() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.AddChainID(arbitrum);
        c3caller.activateChainID(arbitrum);
        bool active = c3caller.isActiveChainID(arbitrum);
        string memory _chainID0 = c3caller.activeChainIDs(0);
        string[] memory allActiveChainIDs = c3caller.getAllActiveChainIDs();
        assertTrue(active);
        assertEq(_chainID0, arbitrum);
        assertEq(allActiveChainIDs.length, 1);
        assertEq(allActiveChainIDs[0], arbitrum);
    }

    function test_AddChainID_RevertWhen_AlreadyActivated() public {
        vm.startPrank(gov);
        c3caller.activateChainID(arbitrum);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_AlreadyChainID.selector, arbitrum));
        c3caller.activateChainID(arbitrum);
        vm.stopPrank();
    }

    // =====================================
    // ======== DEACTIVATE CHAIN ID ========
    // =====================================

    string polygon = "polygon";
    string avalanche = "avalanche";

    function test_DeactivateChainID_State() public {
        vm.startPrank(gov);
        c3caller.activateChainID(arbitrum);
        c3caller.activateChainID(polygon);
        c3caller.activateChainID(avalanche);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.RevokeChainID(polygon);
        c3caller.deactivateChainID(polygon);
        vm.stopPrank();
        bool active = c3caller.isActiveChainID(polygon);
        string memory _chainID0 = c3caller.activeChainIDs(0);
        string memory _chainID1 = c3caller.activeChainIDs(1);
        string[] memory allActiveChainIDs = c3caller.getAllActiveChainIDs();
        assertFalse(active);
        assertEq(_chainID0, arbitrum);
        assertEq(_chainID1, avalanche);
        assertEq(allActiveChainIDs.length, 2);
        assertEq(allActiveChainIDs[0], arbitrum);
        assertEq(allActiveChainIDs[1], avalanche);
    }

    function test_DeactivateChainID_RevertWhen_AlreadyDeactivated() public {
        vm.startPrank(gov);
        c3caller.activateChainID(arbitrum);
        c3caller.activateChainID(polygon);
        c3caller.activateChainID(avalanche);
        c3caller.deactivateChainID(arbitrum);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_IsNotChainID.selector, arbitrum));
        c3caller.deactivateChainID(arbitrum);
        vm.stopPrank();
    }

    // ============================
    // ======== ADD MPC ========
    // ============================

    function test_AddMPC_State() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.AddMPC(mpc1);
        c3caller.addMPC(mpc1);
        bool active = c3caller.isMPCAddr(mpc1);
        address _mpc0 = c3caller.mpcAddrs(0);
        address[] memory allMPCs = c3caller.getAllMPCAddrs();
        assertTrue(active);
        assertEq(_mpc0, mpc1);
        assertEq(allMPCs.length, 1);
        assertEq(allMPCs[0], mpc1);
    }

    function test_AddMPC_RevertWhen_AlreadyActivated() public {
        vm.startPrank(gov);
        c3caller.addMPC(mpc1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_AlreadyMPC.selector, mpc1));
        c3caller.addMPC(mpc1);
        vm.stopPrank();
    }

    // ============================
    // ======== REVOKE MPC ========
    // ============================

    function test_RevokeMPC_State() public {
        vm.startPrank(gov);
        c3caller.addMPC(mpc1);
        c3caller.addMPC(user1);
        c3caller.addMPC(mpc2);
        vm.stopPrank();
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.RevokeMPC(user1);
        c3caller.revokeMPC(user1);
        bool active = c3caller.isMPCAddr(user1);
        address _mpc0 = c3caller.mpcAddrs(0);
        address _mpc1 = c3caller.mpcAddrs(1);
        address[] memory allMPCAddrs = c3caller.getAllMPCAddrs();
        assertFalse(active);
        assertEq(_mpc0, mpc1);
        assertEq(_mpc1, mpc2);
        assertEq(allMPCAddrs.length, 2);
        assertEq(allMPCAddrs[0], mpc1);
        assertEq(allMPCAddrs[1], mpc2);
    }

    function test_RevokeMPC_RevertWhen_AlreadyRevoked() public {
        vm.startPrank(gov);
        c3caller.addMPC(mpc1);
        c3caller.addMPC(user1);
        c3caller.addMPC(mpc2);
        vm.stopPrank();
        vm.startPrank(gov);
        c3caller.revokeMPC(mpc1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_IsNotMPC.selector, mpc1));
        c3caller.revokeMPC(mpc1);
        vm.stopPrank();
    }

    // ========================
    // ======== C3CALL ========
    // ========================

    function test_C3Call_Success() public {
        _activateChainID(gov, "ethereum");
        address target = treasury;
        string memory toChainID = "ethereum";
        string memory outgoingMessage = "C3Call";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, outgoingMessage);
        bytes32 uuid = uuidKeeper.calcCallerUUID(address(c3caller), c3pingDAppID, target.toHexString(), toChainID, data);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogC3Call(c3pingDAppID, uuid, address(c3ping), toChainID, target.toHexString(), data, "");
        bytes32 _uuid = c3ping.mockC3Call(target, toChainID, outgoingMessage);
        assertEq(_uuid, uuid);
    }

    function test_C3Call_RevertWhen_CallerIsNotDAppID() public {
        _activateChainID(gov, "ethereum");
        address target = treasury;
        string memory toChainID = "ethereum";
        string memory outgoingMessage = "C3Call";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, outgoingMessage);
        vm.expectRevert(
            abi.encodeWithSelector(IC3Caller.C3Caller_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.DAppID)
        );
        c3caller.c3call(c3pingDAppID, target.toHexString(), toChainID, data);
    }

    function test_C3Call_RevertWhen_TargetIsZero() public {
        _activateChainID(gov, "ethereum");
        string memory target = "";
        string memory toChainID = "ethereum";
        string memory outgoingMessage = "C3Call";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, outgoingMessage);
        vm.prank(address(c3ping));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.To));
        c3caller.c3call(c3pingDAppID, target, toChainID, data);
    }

    function test_C3Call_RevertWhen_ChainIDIsZero() public {
        _activateChainID(gov, "ethereum");
        address target = treasury;
        string memory toChainID = "";
        string memory outgoingMessage = "C3Call";
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.ChainID));
        c3ping.mockC3Call(target, toChainID, outgoingMessage);
    }

    function test_C3Call_RevertWhen_CalldataIsZero() public {
        _activateChainID(gov, "ethereum");
        address target = treasury;
        string memory toChainID = "ethereum";
        bytes memory data = "";
        vm.prank(address(c3ping));
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.Calldata));
        c3caller.c3call(c3pingDAppID, target.toHexString(), toChainID, data);
    }

    function test_C3Call_RevertWhen_ChainIDInactive() public {
        _activateChainID(gov, "ethereum");
        address target = treasury;
        string memory toChainID = "inactive chain";
        string memory outgoingMessage = "C3Call";
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InactiveChainID.selector, toChainID));
        c3ping.mockC3Call(target, toChainID, outgoingMessage);
    }

    // ===================================
    // ======== C3CALL WITH EXTRA ========
    // ===================================

    function test_C3CallWithExtra_Success() public {
        _activateChainID(gov, "ethereum");
        address target = treasury;
        string memory toChainID = "ethereum";
        string memory outgoingMessage = "C3CallWithExtra";
        string memory extra = "Extra data to emit in LogC3Call";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, outgoingMessage);
        bytes32 uuid = uuidKeeper.calcCallerUUID(address(c3caller), c3pingDAppID, target.toHexString(), toChainID, data);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogC3Call(
            c3pingDAppID, uuid, address(c3ping), toChainID, target.toHexString(), data, bytes(extra)
        );
        bytes32 _uuid = c3ping.mockC3CallWithExtra(target, toChainID, outgoingMessage, extra);
        assertEq(_uuid, uuid);
    }

    // =============================
    // ======== C3BROADCAST ========
    // =============================

    function test_C3Broadcast_Success() public {
        _activateChainID(gov, "ethereum");
        _activateChainID(gov, "polygon");
        _activateChainID(gov, "avalanche");
        address[] memory targets = new address[](3);
        targets[0] = treasury;
        targets[1] = address(c3governor);
        targets[2] = address(c3ping);
        string[] memory toChainIDs = new string[](3);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        toChainIDs[2] = "avalanche";
        string memory outgoingMessage = "C3Broadcast";
        bytes memory data = abi.encodeWithSelector(MockC3CallerDApp.mockC3Executable.selector, outgoingMessage);
        bytes32[] memory uuids = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            bytes32 uuid = uuidKeeper.calcCallerUUIDWithNonce(
                address(c3caller),
                c3pingDAppID,
                targets[i].toHexString(),
                toChainIDs[i],
                data,
                uuidKeeper.currentNonce() + i + 1
            );
            uuids[i] = uuid;
            vm.expectEmit(true, true, true, true);
            emit IC3Caller.LogC3Call(
                c3pingDAppID, uuid, address(c3ping), toChainIDs[i], targets[i].toHexString(), data, ""
            );
        }
        bytes32[] memory _uuids = c3ping.mockC3Broadcast(targets, toChainIDs, outgoingMessage);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(_uuids[i], uuids[i]);
        }
    }

    function test_C3Broadcast_RevertWhen_ZeroToLength() public {
        _activateChainID(gov, "ethereum");
        _activateChainID(gov, "polygon");
        _activateChainID(gov, "avalanche");
        address[] memory targets = new address[](0);
        string[] memory toChainIDs = new string[](3);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        toChainIDs[2] = "avalanche";
        string memory outgoingMessage = "C3Broadcast";
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.To));
        c3ping.mockC3Broadcast(targets, toChainIDs, outgoingMessage);
    }

    function test_C3Broadcast_RevertWhen_ZeroChainIDLength() public {
        _activateChainID(gov, "ethereum");
        _activateChainID(gov, "polygon");
        _activateChainID(gov, "avalanche");
        address[] memory targets = new address[](3);
        targets[0] = treasury;
        targets[1] = address(c3governor);
        targets[2] = address(c3ping);
        string[] memory toChainIDs = new string[](0);
        string memory outgoingMessage = "C3Broadcast";
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.ChainID));
        c3ping.mockC3Broadcast(targets, toChainIDs, outgoingMessage);
    }

    function test_C3Broadcast_RevertWhen_LengthMismatchChainIDTo() public {
        _activateChainID(gov, "ethereum");
        _activateChainID(gov, "polygon");
        _activateChainID(gov, "avalanche");
        address[] memory targets = new address[](3);
        targets[0] = treasury;
        targets[1] = address(c3governor);
        targets[2] = address(c3ping);
        string[] memory toChainIDs = new string[](2);
        toChainIDs[0] = "ethereum";
        toChainIDs[1] = "polygon";
        string memory outgoingMessage = "C3Broadcast";
        vm.expectRevert(
            abi.encodeWithSelector(IC3Caller.C3Caller_LengthMismatch.selector, C3ErrorParam.To, C3ErrorParam.ChainID)
        );
        c3ping.mockC3Broadcast(targets, toChainIDs, outgoingMessage);
    }

    // =========================
    // ======== EXECUTE ========
    // =========================

    function test_Execute_Success() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory exec = _getMockC3EvmMessage();
        uint256 poolBefore = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasPrice = _setGasPrice(1 gwei);
        vm.prank(mpc1);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecCall(
            c3pingDAppID, exec.to, exec.uuid, exec.fromChainID, exec.sourceTx, exec.data, true, ""
        );
        c3caller.execute(c3pingDAppID, exec);
        uint256 poolAfter = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasUnitsSpent = 25993;
        uint256 expectedFee = gasUnitsSpent * gasPrice * dappManager.gasPerEtherFee(address(usdc)) / 1 ether;
        assertApproxEqRel(poolAfter, poolBefore - expectedFee, 0.1 ether);
        string memory _setMessage = c3ping.incomingMessage();
        assertEq(_setMessage, "Incoming message");
        assertEq(c3ping.uuid(), exec.uuid);
        assertEq(c3ping.fromChainID(), exec.fromChainID);
        assertEq(c3ping.sourceTx(), exec.sourceTx);
    }

    function test_Execute_RevertWhen_DataIsZero() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory exec = _getMockC3EvmMessage();
        exec.data = "";
        vm.prank(mpc1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.Calldata));
        c3caller.execute(c3pingDAppID, exec);
    }

    function test_Execute_RevertWhen_InvalidDAppID() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory exec = _getMockC3EvmMessage();
        vm.prank(mpc1);
        vm.expectRevert(
            abi.encodeWithSelector(IC3Caller.C3Caller_InvalidDAppID.selector, c3pingDAppID, c3governorDAppID)
        );
        c3caller.execute(c3governorDAppID, exec);
    }

    function test_Execute_RevertWhen_UUIDAlreadyCompleted() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory exec = _getMockC3EvmMessage();
        bytes32 usedUUID = keccak256("used uuid");
        exec.uuid = usedUUID;
        vm.prank(address(c3caller));
        uuidKeeper.registerUUID(usedUUID, c3pingDAppID);
        vm.prank(mpc1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_UUIDAlreadyCompleted.selector, usedUUID));
        c3caller.execute(c3pingDAppID, exec);
    }

    function test_Execute_RevertWhen_InsufficientGasFee() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory exec = _getMockC3EvmMessage();
        vm.prank(gov);
        dappManager.withdraw(c3pingDAppID, address(usdc));
        uint256 gasPrice = _setGasPrice(1 gwei);
        uint256 gasUnitsSpent = 96970;
        uint256 expectedFee = gasUnitsSpent * gasPrice * dappManager.gasPerEtherFee(address(usdc)) / 1 ether;
        vm.prank(mpc1);
        bytes4 expectedErrorSelector = IC3DAppManager.C3DAppManager_InsufficientBalance.selector;
        (bool success, bytes memory result) =
            address(c3caller).call(abi.encodeWithSelector(IC3Caller.execute.selector, c3pingDAppID, exec));
        assertFalse(success);
        assertEq(result.length, 68);
        bytes4 _selector = bytes4(result);
        uint256 _pool;
        uint256 _bill;
        assembly {
            let data := add(result, 0x20)
            _pool := mload(add(data, 0x04))
            _bill := mload(add(data, 0x24))
        }
        assertEq(_selector, expectedErrorSelector);
        assertEq(_pool, 0);
        assertApproxEqRel(_bill, expectedFee, 0.1 ether);
    }

    function test_Execute_UnsuccessfulCall() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory exec = _getMockC3EvmMessageRevert();
        uint256 poolBefore = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasPrice = _setGasPrice(1 gwei);
        bytes memory result = abi.encodeWithSelector(MockC3CallerDApp.TargetCallFailed.selector);
        vm.prank(mpc1);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogFallbackCall(
            c3pingDAppID,
            exec.uuid,
            exec.fallbackTo,
            abi.encodeWithSelector(IC3CallerDApp.c3Fallback.selector, c3pingDAppID, exec.data, result),
            result
        );
        c3caller.execute(c3pingDAppID, exec);
        uint256 poolAfter = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasUnitsSpent = 3044;
        uint256 expectedFee = gasUnitsSpent * gasPrice * dappManager.gasPerEtherFee(address(usdc)) / 1 ether;
        assertApproxEqRel(poolAfter, poolBefore - expectedFee, 0.1 ether);
        string memory _setMessage = c3ping.incomingMessage();
        assertEq(_setMessage, "");
    }

    // ============================
    // ======== C3FALLBACK ========
    // ============================

    function test_C3Fallback_Success() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory c3fallback = _getMockC3EvmMessage();
        bytes memory res = abi.encodeWithSelector(MockC3CallerDApp.TargetCallFailed.selector);
        c3fallback.data = abi.encodeWithSelector(IC3CallerDApp.c3Fallback.selector, c3pingDAppID, c3fallback.data, res);
        uint256 poolBefore = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasPrice = _setGasPrice(1 gwei);
        vm.prank(mpc1);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecFallback(
            c3pingDAppID,
            c3fallback.to,
            c3fallback.uuid,
            c3fallback.fromChainID,
            c3fallback.sourceTx,
            c3fallback.data,
            abi.encode(true)
        );
        c3caller.c3Fallback(c3pingDAppID, c3fallback);
        uint256 poolAfter = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasUnitsSpent = 50364;
        uint256 expectedFee = gasUnitsSpent * gasPrice * dappManager.gasPerEtherFee(address(usdc)) / 1 ether;
        assertApproxEqRel(poolAfter, poolBefore - expectedFee, 0.1 ether);
        string memory _setMessage = c3ping.fallbackMessage();
        assertEq(_setMessage, "Incoming message");
        assertEq(c3ping.uuid(), c3fallback.uuid);
        assertEq(c3ping.fromChainID(), c3fallback.fromChainID);
        assertEq(c3ping.sourceTx(), c3fallback.sourceTx);
    }

    function test_C3Fallback_RevertWhen_DataIsZero() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory c3fallback = _getMockC3EvmMessage();
        c3fallback.data = "";
        vm.prank(mpc1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_InvalidLength.selector, C3ErrorParam.Calldata));
        c3caller.c3Fallback(c3pingDAppID, c3fallback);
    }

    function test_C3Fallback_RevertWhen_InvalidDAppID() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory c3fallback = _getMockC3EvmMessage();
        vm.prank(mpc1);
        vm.expectRevert(
            abi.encodeWithSelector(IC3Caller.C3Caller_InvalidDAppID.selector, c3pingDAppID, c3governorDAppID)
        );
        c3caller.c3Fallback(c3governorDAppID, c3fallback);
    }

    function test_C3Fallback_RevertWhen_UUIDAlreadyCompleted() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory c3fallback = _getMockC3EvmMessage();
        bytes32 usedUUID = keccak256("used uuid");
        c3fallback.uuid = usedUUID;
        vm.prank(address(c3caller));
        uuidKeeper.registerUUID(usedUUID, c3pingDAppID);
        vm.prank(mpc1);
        vm.expectRevert(abi.encodeWithSelector(IC3Caller.C3Caller_UUIDAlreadyCompleted.selector, usedUUID));
        c3caller.c3Fallback(c3pingDAppID, c3fallback);
    }

    function test_C3Fallback_RevertWhen_InsufficientGasFee() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory c3fallback = _getMockC3EvmMessage();
        vm.prank(gov);
        dappManager.withdraw(c3pingDAppID, address(usdc));
        uint256 gasPrice = _setGasPrice(1 gwei);
        uint256 gasUnitsSpent = 97488;
        uint256 expectedFee = gasUnitsSpent * gasPrice * dappManager.gasPerEtherFee(address(usdc)) / 1 ether;
        vm.prank(mpc1);
        bytes4 expectedErrorSelector = IC3DAppManager.C3DAppManager_InsufficientBalance.selector;
        (bool success, bytes memory result) =
            address(c3caller).call(abi.encodeWithSelector(IC3Caller.c3Fallback.selector, c3pingDAppID, c3fallback));
        assertFalse(success);
        assertEq(result.length, 68);
        bytes4 _selector = bytes4(result);
        uint256 _pool;
        uint256 _bill;
        assembly {
            let data := add(result, 0x20)
            _pool := mload(add(data, 0x04))
            _bill := mload(add(data, 0x24))
        }
        assertEq(_selector, expectedErrorSelector);
        assertEq(_pool, 0);
        assertApproxEqRel(_bill, expectedFee, 0.1 ether);
    }

    function test_C3Fallback_UnsuccessfulCall() public {
        _addMPC(mpc1);
        IC3Caller.C3EvmMessage memory c3fallback = _getMockC3EvmMessage();
        uint256 poolBefore = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasPrice = _setGasPrice(1 gwei);
        bytes4 _selector = bytes4(keccak256(abi.encodePacked("unknownSelector()")));
        bytes memory _unknownSelectorData = abi.encodeWithSelector(_selector);
        c3fallback.data =
            abi.encodeWithSelector(IC3CallerDApp.c3Fallback.selector, c3pingDAppID, _unknownSelectorData, "");
        vm.prank(mpc1);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogExecFallback(
            c3pingDAppID,
            c3fallback.to,
            c3fallback.uuid,
            c3fallback.fromChainID,
            c3fallback.sourceTx,
            c3fallback.data,
            abi.encode(false)
        );
        c3caller.c3Fallback(c3pingDAppID, c3fallback);
        uint256 poolAfter = dappManager.dappStakePool(c3pingDAppID, address(usdc));
        uint256 gasUnitsSpent = 26948;
        uint256 expectedFee = gasUnitsSpent * gasPrice * dappManager.gasPerEtherFee(address(usdc)) / 1 ether;
        assertApproxEqRel(poolAfter, poolBefore - expectedFee, 0.1 ether);
        string memory _setMessage = c3ping.incomingMessage();
        assertEq(_setMessage, "");
        bytes4 failedSelector = c3ping.selector();
        assertEq(failedSelector, _selector);
    }
}
