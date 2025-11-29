// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {C3Caller} from "../../src/C3Caller.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {C3DAppManager} from "../../src/dapp/C3DAppManager.sol";
import {C3CallerUpgradeable} from "../../src/upgradeable/C3CallerUpgradeable.sol";
import {C3UUIDKeeperUpgradeable} from "../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {C3DAppManagerUpgradeable} from "../../src/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {MockC3GovClientUpgradeable} from "../mocks/MockC3GovClientUpgradeable.sol";
import {MockC3CallerDApp} from "../mocks/MockC3CallerDApp.sol";
import {MockC3GovernDApp} from "../mocks/MockC3GovernDApp.sol";
import {MockC3CallerDAppUpgradeable} from "../mocks/MockC3CallerDAppUpgradeable.sol";
import {MockC3GovernDAppUpgradeable} from "../mocks/MockC3GovernDAppUpgradeable.sol";
import {ITestERC20} from "../mocks/ITestERC20.sol";
import {C3CallerProxy} from "../../src/utils/C3CallerProxy.sol";

import {Utils} from "./Utils.sol";

contract Deployer is Utils {
    C3UUIDKeeper uuidKeeper;
    C3DAppManager dappManager;
    C3Caller c3caller;

    C3UUIDKeeperUpgradeable uuidKeeper_u;
    C3DAppManagerUpgradeable dappManager_u;
    C3CallerUpgradeable c3caller_u;

    function _deployC3UUIDKeeper(address _gov) internal {
        vm.prank(_gov);
        uuidKeeper = new C3UUIDKeeper();
    }

    function _deployC3DAppManager(address _gov) internal {
        vm.prank(_gov);
        dappManager = new C3DAppManager();
    }

    function _setC3Caller(address _gov) internal {
        vm.startPrank(_gov);
        uuidKeeper.setC3Caller(address(c3caller));
        dappManager.setC3Caller(address(c3caller));
        vm.stopPrank();
    }

    function _deployC3Caller(address _gov) internal {
        vm.prank(_gov);
        c3caller = new C3Caller(address(uuidKeeper), address(dappManager));
    }

    function _activateChainID(address _gov, string memory _chainID) internal {
        vm.prank(_gov);
        c3caller.activateChainID(_chainID);
    }

    function _addMPC(address _gov, address _mpc) internal {
        vm.prank(_gov);
        c3caller.addMPC(_mpc);
    }

    function _setFeeConfig(address _gov, address _feeToken) internal {
        uint256 perByteFee = 10 ** (ITestERC20(_feeToken).decimals() - 2); // 0.01 USDC per byte of calldata payload
        uint256 perGasFee = 2000 * 10 ** ITestERC20(_feeToken).decimals(); // 2000 USDC per ether of gas spent
        vm.startPrank(_gov);
        dappManager.setFeeConfig(_feeToken, perByteFee, perGasFee);
        vm.stopPrank();
    }

    function _deployC3CallerDApp(address _creator, uint256 _dappID) internal returns (MockC3CallerDApp) {
        vm.prank(_creator);
        return new MockC3CallerDApp(address(c3caller), _dappID);
    }

    function _deployC3GovernDApp(address _creator, address _gov, uint256 _dappID) internal returns (MockC3GovernDApp) {
        vm.prank(_creator);
        return new MockC3GovernDApp(_gov, address(c3caller), _dappID);
    }

    function _initDAppConfig(address _creator, string memory _dappKey, address _feeToken, string memory _metadata)
        internal
        returns (uint256)
    {
        vm.prank(_creator);
        return dappManager.initDAppConfig(_dappKey, _feeToken, _metadata);
    }

    function _createC3CallerDApp(address _creator, string memory _dappKey, address _feeToken, string memory _metadata)
        internal
        returns (MockC3CallerDApp, uint256)
    {
        uint256 dappID = _initDAppConfig(_creator, _dappKey, _feeToken, _metadata);
        MockC3CallerDApp dapp = _deployC3CallerDApp(_creator, dappID);
        vm.startPrank(_creator);
        dappManager.setDAppAddr(dappID, address(dapp), true);
        ITestERC20(_feeToken).approve(address(dappManager), type(uint256).max);
        dappManager.deposit(dappID, _feeToken, 100 * 10 ** ITestERC20(_feeToken).decimals());
        vm.stopPrank();
        return (dapp, dappID);
    }

    function _createC3GovernDApp(
        address _creator,
        address _gov,
        string memory _dappKey,
        address _feeToken,
        string memory _metadata
    ) internal returns (MockC3GovernDApp, uint256) {
        uint256 dappID = _initDAppConfig(_gov, _dappKey, _feeToken, _metadata);
        MockC3GovernDApp dapp = _deployC3GovernDApp(_creator, _gov, dappID);
        vm.startPrank(_creator);
        dappManager.setDAppAddr(dappID, address(dapp), true);
        dappManager.deposit(dappID, _feeToken, 100 * 10 ** ITestERC20(_feeToken).decimals());
        vm.stopPrank();
        return (dapp, dappID);
    }

    function _deployC3UUIDKeeperUpgradeable(address _gov) internal {
        vm.startPrank(_gov);
        C3UUIDKeeperUpgradeable impl = new C3UUIDKeeperUpgradeable();
        bytes memory initData = abi.encodeWithSelector(C3UUIDKeeperUpgradeable.initialize.selector);
        C3CallerProxy proxy = new C3CallerProxy(address(impl), initData);
        uuidKeeper_u = C3UUIDKeeperUpgradeable(address(proxy));
        vm.stopPrank();
    }

    function _deployC3DAppManagerUpgradeable(address _gov) internal {
        vm.startPrank(_gov);
        C3DAppManagerUpgradeable impl = new C3DAppManagerUpgradeable();
        bytes memory initData = abi.encodeWithSelector(C3DAppManagerUpgradeable.initialize.selector);
        C3CallerProxy proxy = new C3CallerProxy(address(impl), initData);
        dappManager_u = C3DAppManagerUpgradeable(address(proxy));
        vm.stopPrank();
    }

    function _deployC3CallerUpgradeable(address _gov) internal {
        vm.startPrank(_gov);
        C3CallerUpgradeable impl = new C3CallerUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            C3CallerUpgradeable.initialize.selector, address(uuidKeeper_u), address(dappManager_u)
        );
        C3CallerProxy proxy = new C3CallerProxy(address(impl), initData);
        c3caller_u = C3CallerUpgradeable(address(proxy));
        vm.stopPrank();
    }

    function _setC3CallerUpgradeable(address _gov) internal {
        vm.startPrank(_gov);
        uuidKeeper_u.setC3Caller(address(c3caller_u));
        dappManager_u.setC3Caller(address(c3caller_u));
        vm.stopPrank();
    }

    function _activateChainIDUpgradeable(address _gov, string memory _chainID) internal {
        vm.prank(_gov);
        c3caller_u.activateChainID(_chainID);
    }

    function _addMPCUpgradeable(address _gov, address _mpc) internal {
        vm.prank(_gov);
        c3caller_u.addMPC(_mpc);
    }

    function _setFeeConfigUpgradeable(address _gov, address _feeToken) internal {
        uint256 perByteFee = 10 ** (ITestERC20(_feeToken).decimals() - 2); // 0.01 USDC per byte of calldata payload
        uint256 perGasFee = 2000 * 10 ** ITestERC20(_feeToken).decimals(); // 2000 USDC per ether of gas spent
        vm.startPrank(_gov);
        dappManager_u.setFeeConfig(_feeToken, perByteFee, perGasFee);
        vm.stopPrank();
    }

    function _deployC3CallerDAppUpgradeable(address _creator, uint256 _dappID)
        internal
        returns (MockC3CallerDAppUpgradeable)
    {
        vm.startPrank(_creator);
        MockC3CallerDAppUpgradeable impl = new MockC3CallerDAppUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(MockC3CallerDAppUpgradeable.initialize.selector, address(c3caller_u), _dappID);
        C3CallerProxy proxy = new C3CallerProxy(address(impl), initData);
        vm.stopPrank();
        return MockC3CallerDAppUpgradeable(address(proxy));
    }

    function _deployC3GovernDAppUpgradeable(address _creator, address _gov, uint256 _dappID)
        internal
        returns (MockC3GovernDAppUpgradeable)
    {
        vm.startPrank(_creator);
        MockC3GovernDAppUpgradeable impl = new MockC3GovernDAppUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(MockC3GovernDAppUpgradeable.initialize.selector, _gov, address(c3caller_u), _dappID);
        C3CallerProxy proxy = new C3CallerProxy(address(impl), initData);
        vm.stopPrank();
        return MockC3GovernDAppUpgradeable(address(proxy));
    }

    function _deployC3GovClientUpgradeable(address _creator, address _gov)
        internal
        returns (MockC3GovClientUpgradeable)
    {
        vm.startPrank(_creator);
        MockC3GovClientUpgradeable impl = new MockC3GovClientUpgradeable();
        bytes memory initData = abi.encodeWithSelector(MockC3GovClientUpgradeable.initialize.selector, _gov);
        C3CallerProxy proxy = new C3CallerProxy(address(impl), initData);
        vm.stopPrank();
        return MockC3GovClientUpgradeable(address(proxy));
    }

    function _initDAppConfigUpgradeable(
        address _creator,
        string memory _dappKey,
        address _feeToken,
        string memory _metadata
    ) internal returns (uint256) {
        vm.prank(_creator);
        return dappManager_u.initDAppConfig(_dappKey, _feeToken, _metadata);
    }

    function _createC3CallerDAppUpgradeable(
        address _creator,
        string memory _dappKey,
        address _feeToken,
        string memory _metadata
    ) internal returns (MockC3CallerDAppUpgradeable, uint256) {
        uint256 dappID = _initDAppConfigUpgradeable(_creator, _dappKey, _feeToken, _metadata);
        MockC3CallerDAppUpgradeable dapp = _deployC3CallerDAppUpgradeable(_creator, dappID);
        vm.startPrank(_creator);
        dappManager_u.setDAppAddr(dappID, address(dapp), true);
        ITestERC20(_feeToken).approve(address(dappManager_u), type(uint256).max);
        dappManager_u.deposit(dappID, _feeToken, 100 * 10 ** ITestERC20(_feeToken).decimals());
        vm.stopPrank();
        return (dapp, dappID);
    }

    function _createC3GovernDAppUpgradeable(
        address _creator,
        address _gov,
        string memory _dappKey,
        address _feeToken,
        string memory _metadata
    ) internal returns (MockC3GovernDAppUpgradeable, uint256) {
        uint256 dappID = _initDAppConfigUpgradeable(_gov, _dappKey, _feeToken, _metadata);
        MockC3GovernDAppUpgradeable dapp = _deployC3GovernDAppUpgradeable(_creator, _gov, dappID);
        vm.startPrank(_creator);
        dappManager_u.setDAppAddr(dappID, address(dapp), true);
        dappManager_u.deposit(dappID, _feeToken, 100 * 10 ** ITestERC20(_feeToken).decimals());
        vm.stopPrank();
        return (dapp, dappID);
    }
}
