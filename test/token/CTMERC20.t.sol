// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Helpers} from "../helpers/Helpers.sol";
import {ICTMERC20, CTMERC20} from "../../src/token/CTMERC20.sol";
import {IC3GovernDApp} from "../../src/gov/IC3GovernDApp.sol";
import {IC3CallerDApp} from "../../src/dapp/IC3CallerDApp.sol";
import {IC3Caller} from "../../src/IC3Caller.sol";
import {C3ErrorParam, C3CallerUtils} from "../../src/utils/C3CallerUtils.sol";

contract MockCTMERC20 is CTMERC20 {
    constructor (
        string memory _name,
        string memory _symbol,
        address _c3caller,
        uint256 _dappID
    ) CTMERC20(_name, _symbol, _c3caller, _dappID) {
        _incrementGlobalSupply(100 ether);
        _mint(msg.sender, 100 ether);
    }

    function mint(address _to, uint256 _amount) public {
        _incrementGlobalSupply(_amount);
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        _decrementGlobalSupply(_amount);
        _burn(_from, _amount);
    }
}

contract CTMERC20Test is Helpers {
    using Strings for address;

    address user;

    uint256 ctmerc20DAppID;
    MockCTMERC20 ctmerc20;

    function setUp() public virtual override {
        super.setUp();

        user = makeAddr("user");

        // Deploy C3UUIDKeeper, C3DAppManager and C3Caller
        _deployC3UUIDKeeper(gov);
        _deployC3DAppManager(gov);
        _deployC3Caller(gov);

        // Set C3Caller address in UUIDKeeper and DAppManager
        _setC3Caller(gov);

        // Set USDC and CTM as valid fee tokens
        _setFeeConfig(gov, address(usdc));
        _setFeeConfig(gov, address(ctm));

        string memory dappKey = "v1.c3caller.ctmerc20";
        string memory metadata =
            "{'version':1,'name':'CTMERC20','description':'Cross-chain ERC20 token','email':'admin@example.com','url':'example.com'}";

        ctmerc20DAppID = _initDAppConfig(gov, dappKey, address(usdc), metadata);

        vm.prank(gov);
        usdc.approve(address(dappManager), type(uint256).max);

        // Deploy CTMERC20 with gov as the governance contract
        vm.startPrank(gov);
        ctmerc20 = new MockCTMERC20(
            "MockCTMERC20",
            "CTM",
            address(c3caller),
            ctmerc20DAppID
        );
        dappManager.setDAppAddr(ctmerc20DAppID, address(ctmerc20), true);
        dappManager.deposit(ctmerc20DAppID, address(usdc), 100 * 10 ** usdc.decimals());
        vm.stopPrank();

        vm.startPrank(gov);
        c3caller.activateChainID("1");
        // c3caller.activateChainID("10");
        // c3caller.activateChainID("56");
        // c3caller.activateChainID("137");
        // c3caller.activateChainID("421614");
        ctmerc20.setPeer("1", "0xaabbccddaabbccddaabbccddaabbccddaabbccdd");
        // ctmerc20.setPeer("10", "0xbbccddeebbccddeebbccddeebbccddeebbccddee");
        // ctmerc20.setPeer("56", "0xccddeeffccddeeffccddeeffccddeeffccddeeff");
        // ctmerc20.setPeer("137", "0xddeeff00ddeeff00ddeeff00ddeeff00ddeeff00");
        // ctmerc20.setPeer("421614", "0xeeff0011eeff0011eeff0011eeff0011eeff0011");
        vm.stopPrank();
    }

    function test_Deployment() public view {
        assertEq(ctmerc20.globalSupply(), 100 ether);
        assertEq(ctmerc20.peers("1"), "0xaabbccddaabbccddaabbccddaabbccddaabbccdd");
    }

    function test_SetPeer() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.SetPeer("0", "0xabc");
        ctmerc20.setPeer("0", "0xabc");
    }

    // ==================================
    // ======== ACCESS MODIFIERS ========
    // ==================================

    function test_SetPeer_RevertWhen_CallerNotGov() public {
        vm.expectRevert(abi.encodeWithSelector(IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov));
        ctmerc20.setPeer("0", "0xabc");
    }

    function test_C3Receive_RevertWhen_CallerNotC3Caller() public {
        vm.expectRevert(abi.encodeWithSelector(IC3CallerDApp.C3CallerDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller));
        ctmerc20.c3receive("from_account", "to_account", 100);
    }

    // =============================
    // ======== C3 TRANSFER ========
    // =============================

    function test_C3Transfer_Success() public {
        ctmerc20.mint(address(this), 100 ether);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(address(this), "to_account", 1 ether, "1");
        ctmerc20.c3transfer("to_account", 1 ether, "1");
    }

    function test_C3Transfer_RevertWhen_InvalidChainId() public {
        string memory invalidChainId = "2";
        vm.expectRevert(abi.encodeWithSelector(ICTMERC20.CTMERC20_InvalidChainID.selector, invalidChainId));
        ctmerc20.c3transfer("to_account", 1 ether, invalidChainId);
    }

    function test_C3Transfer_RevertWhen_ToZeroLength() public {
        string memory toZeroLength = "";
        vm.expectRevert(abi.encodeWithSelector(ICTMERC20.CTMERC20_InvalidLength.selector, C3ErrorParam.To));
        ctmerc20.c3transfer(toZeroLength, 1 ether, "1");
    }

    function test_C3Transfer_RevertWhen_InsufficientBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, 100 ether));
        ctmerc20.c3transfer("to_account", 100 ether, "1");
    }

    // =============================
    // ======== C3 TRANSFER ========
    // =============================

    function test_C3TransferFrom_Success() public {
        ctmerc20.mint(address(user), 100 ether);
        vm.prank(user);
        ctmerc20.approve(address(this), 100 ether);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(user, "to_account", 1 ether, "1");
        ctmerc20.c3transferFrom(user, "to_account", 1 ether, "1");
    }

    function test_C3TransferFrom_RevertWhen_InvalidChainId() public {
        string memory invalidChainId = "2";
        vm.expectRevert(abi.encodeWithSelector(ICTMERC20.CTMERC20_InvalidChainID.selector, invalidChainId));
        ctmerc20.c3transferFrom(user, "to_account", 1 ether, invalidChainId);
    }

    function test_C3TransferFrom_RevertWhen_ToZeroLength() public {
        string memory toZeroLength = "";
        vm.expectRevert(abi.encodeWithSelector(ICTMERC20.CTMERC20_InvalidLength.selector, C3ErrorParam.To));
        ctmerc20.c3transferFrom(user, toZeroLength, 1 ether, "1");
    }

    function test_C3TransferFrom_RevertWhen_InsufficientBalance() public {
        vm.prank(user);
        ctmerc20.approve(address(this), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 0, 100 ether));
        ctmerc20.c3transferFrom(user, "to_account", 100 ether, "1");
    }

    function test_C3TransferFrom_RevertWhen_InsufficientAllowance() public {
        ctmerc20.mint(address(user), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 100 ether));
        ctmerc20.c3transferFrom(user, "to_account", 100 ether, "1");
    }

    // ==========================================
    // ======== EXTENDED COVERAGE (NEW) ========
    // ==========================================

    function _addMPC(address _mpc) internal {
        vm.prank(gov);
        c3caller.addMPC(_mpc);
    }

    // =============================
    // ======== ERC20 METADATA =====
    // =============================

    function test_ERC20_Metadata() public view {
        assertEq(ctmerc20.name(), "MockCTMERC20");
        assertEq(ctmerc20.symbol(), "CTM");
        assertEq(ctmerc20.decimals(), 18);
    }

    function test_ERC20_TotalSupply() public view {
        assertEq(ctmerc20.totalSupply(), 100 ether);
    }

    // =============================
    // ======== INHERITED STATE =====
    // =============================

    function test_InheritedState() public view {
        assertEq(ctmerc20.gov(), gov);
        assertEq(ctmerc20.c3caller(), address(c3caller));
        assertEq(ctmerc20.dappID(), ctmerc20DAppID);
        assertEq(ctmerc20.balanceOf(gov), 100 ether);
    }

    // =============================
    // ======== ERC20 TRANSFERS =====
    // =============================

    function test_ERC20_Transfer() public {
        vm.prank(gov);
        ctmerc20.transfer(user, 10 ether);
        assertEq(ctmerc20.balanceOf(gov), 90 ether);
        assertEq(ctmerc20.balanceOf(user), 10 ether);
    }

    function test_ERC20_TransferFrom() public {
        ctmerc20.mint(user, 20 ether);
        vm.prank(user);
        ctmerc20.approve(address(this), 15 ether);
        ctmerc20.transferFrom(user, address(this), 15 ether);
        assertEq(ctmerc20.balanceOf(user), 5 ether);
        assertEq(ctmerc20.balanceOf(address(this)), 15 ether);
        assertEq(ctmerc20.allowance(user, address(this)), 0);
    }

    function test_ERC20_Approve() public {
        vm.prank(user);
        ctmerc20.approve(address(this), 50 ether);
        assertEq(ctmerc20.allowance(user, address(this)), 50 ether);
    }

    // =============================
    // ======== GLOBAL SUPPLY ========
    // =============================

    function test_GlobalSupply_MintAndBurn() public {
        uint256 supplyBefore = ctmerc20.globalSupply();
        ctmerc20.mint(user, 50 ether);
        assertEq(ctmerc20.globalSupply(), supplyBefore + 50 ether);
        assertEq(ctmerc20.balanceOf(user), 50 ether);
        ctmerc20.burn(user, 20 ether);
        assertEq(ctmerc20.globalSupply(), supplyBefore + 30 ether);
        assertEq(ctmerc20.balanceOf(user), 30 ether);
    }

    function test_GlobalSupply_UnchangedOnC3Transfer() public {
        uint256 globalSupplyBefore = ctmerc20.globalSupply();
        vm.prank(gov);
        ctmerc20.c3transfer(user.toHexString(), 1 ether, "1");
        assertEq(ctmerc20.globalSupply(), globalSupplyBefore);
    }

    // =============================
    // ======== SET PEER STATE =====
    // =============================

    function test_SetPeer_UpdatesPeersMapping() public {
        vm.prank(gov);
        ctmerc20.setPeer("42", "0xdeadbeef");
        assertEq(ctmerc20.peers("42"), "0xdeadbeef");
    }

    // =============================
    // ======== C3 RECEIVE =========
    // =============================

    function test_C3Receive_Success() public {
        uint256 amount = 5 ether;
        string memory fromStr = gov.toHexString();
        string memory toStr = user.toHexString();
        uint256 balanceBefore = ctmerc20.balanceOf(user);

        vm.prank(address(c3caller));
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Receive(fromStr, user, amount, "");
        ctmerc20.c3receive(fromStr, toStr, amount);

        assertEq(ctmerc20.balanceOf(user), balanceBefore + amount);
        assertEq(ctmerc20.totalSupply(), 100 ether + amount);
    }

    function test_C3Receive_RevertWhen_InvalidToAddress() public {
        vm.prank(address(c3caller));
        vm.expectRevert(C3CallerUtils.C3CallerUtils_OutOfBounds.selector);
        ctmerc20.c3receive(gov.toHexString(), "not-a-valid-address", 1 ether);
    }

    function test_C3Receive_ViaExecute() public {
        _addMPC(mpc1);
        vm.txGasPrice(1 gwei);
        uint256 amount = 3 ether;
        string memory fromStr = gov.toHexString();
        string memory toStr = user.toHexString();
        bytes memory data = abi.encodeWithSelector(ctmerc20.c3receive.selector, fromStr, toStr, amount);
        bytes32 uuid = keccak256("ctmerc20-receive");
        IC3Caller.C3EvmMessage memory message = IC3Caller.C3EvmMessage(
            uuid, address(ctmerc20), "1", "source-tx-hash", gov.toHexString(), data
        );

        vm.prank(mpc1);
        c3caller.execute(ctmerc20DAppID, message);

        assertEq(ctmerc20.balanceOf(user), amount);
    }

    // =============================
    // ======== C3 TRANSFER STATE ==
    // =============================

    function test_C3Transfer_BurnsBalanceAndReturnsTrue() public {
        uint256 transferAmount = 1 ether;
        uint256 balanceBefore = ctmerc20.balanceOf(gov);

        vm.prank(gov);
        bool success = ctmerc20.c3transfer(user.toHexString(), transferAmount, "1");

        assertTrue(success);
        assertEq(ctmerc20.balanceOf(gov), balanceBefore - transferAmount);
    }

    function test_C3Transfer_EmitsLogC3Call() public {
        string memory toStr = user.toHexString();
        string memory toChainID = "1";
        string memory peer = ctmerc20.peers(toChainID);
        uint256 amount = 1 ether;
        bytes memory receiveCall =
            abi.encodeWithSelector(ctmerc20.c3receive.selector, gov.toHexString(), toStr, amount);
        bytes32 uuid = uuidKeeper.calcCallerUUID(address(c3caller), ctmerc20DAppID, peer, toChainID, receiveCall);

        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit IC3Caller.LogC3Call(ctmerc20DAppID, uuid, address(ctmerc20), toChainID, peer, receiveCall, "");
        ctmerc20.c3transfer(toStr, amount, toChainID);
    }

    function test_C3TransferFrom_BurnsBalanceAndAllowance() public {
        uint256 transferAmount = 2 ether;
        ctmerc20.mint(user, 10 ether);
        vm.prank(user);
        ctmerc20.approve(address(this), 5 ether);

        bool success = ctmerc20.c3transferFrom(user, user.toHexString(), transferAmount, "1");

        assertTrue(success);
        assertEq(ctmerc20.balanceOf(user), 8 ether);
        assertEq(ctmerc20.allowance(user, address(this)), 3 ether);
    }

    // =============================
    // ======== C3 FALLBACK ========
    // =============================

    function test_C3Fallback_RevertWhen_CallerNotC3Caller() public {
        bytes memory data =
            abi.encodeWithSelector(ctmerc20.c3receive.selector, gov.toHexString(), user.toHexString(), 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3CallerDApp.C3CallerDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller
            )
        );
        ctmerc20.c3Fallback(ctmerc20DAppID, data, "");
    }

    function test_C3Fallback_C3Receive_RefundsSender() public {
        uint256 amount = 2 ether;
        string memory fromStr = gov.toHexString();
        string memory toStr = user.toHexString();
        bytes memory data = abi.encodeWithSelector(ctmerc20.c3receive.selector, fromStr, toStr, amount);
        bytes memory reason = abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 0, amount);
        uint256 balanceBefore = ctmerc20.balanceOf(gov);

        vm.prank(address(c3caller));
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Refund(gov, toStr, amount, reason);
        bool handled = ctmerc20.c3Fallback(ctmerc20DAppID, data, reason);

        assertTrue(handled);
        assertEq(ctmerc20.balanceOf(gov), balanceBefore + amount);
    }

    function test_C3Fallback_WrongSelector_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(ctmerc20.c3transfer.selector, user.toHexString(), 1 ether, "1");
        vm.prank(address(c3caller));
        bool handled = ctmerc20.c3Fallback(ctmerc20DAppID, data, "");
        assertFalse(handled);
    }

    function test_C3Fallback_InvalidDAppID() public {
        bytes memory data =
            abi.encodeWithSelector(ctmerc20.c3receive.selector, gov.toHexString(), user.toHexString(), 1 ether);
        uint256 wrongDAppID = ctmerc20DAppID + 1;
        vm.prank(address(c3caller));
        vm.expectRevert(
            abi.encodeWithSelector(IC3CallerDApp.C3CallerDApp_InvalidDAppID.selector, ctmerc20DAppID, wrongDAppID)
        );
        ctmerc20.c3Fallback(wrongDAppID, data, "");
    }

    function test_C3Fallback_DataLessThan4Bytes_ReturnsFalse() public {
        vm.prank(address(c3caller));
        bool handled = ctmerc20.c3Fallback(ctmerc20DAppID, "", "");
        assertFalse(handled);
    }
}
