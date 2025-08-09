// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {console} from "forge-std/console.sol";

import {C3Caller} from "../../src/C3Caller.sol";
import {IC3Caller} from "../../src/IC3Caller.sol";
import {C3CallerUpgradeable} from "../../src/upgradeable/C3CallerUpgradeable.sol";
import {IC3CallerProxy} from "../../src/utils/IC3CallerProxy.sol";

import {C3UUIDKeeperUpgradeable} from "../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";

import {MockC3CallerDApp} from "../helpers/mocks/MockC3CallerDApp.sol";

import {Helpers} from "../helpers/Helpers.sol";

contract C3CallerUpgradeableV2 is C3CallerUpgradeable {
    // New storage variable to test storage layout compatibility
    uint256 public newStorageVariable;

    function initializeV2() public reinitializer(2) {
        newStorageVariable = 0;
    }

    // New function to test upgrade functionality
    function setNewStorageVariable(uint256 _value) external {
        newStorageVariable = _value;
    }

    function getNewStorageVariable() external view returns (uint256) {
        return newStorageVariable;
    }

    // Override _authorizeUpgrade to allow testing
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOperator {}
}

contract C3CallerUpgradeableV3 is C3CallerUpgradeableV2 {
    // Another storage variable to test multiple upgrades
    string public version;

    function initializeV3() public reinitializer(3) {
        version = "";
    }

    function setVersion(string calldata _version) external {
        version = _version;
    }

    function getVersion() external view returns (string memory) {
        return version;
    }

    // Override _authorizeUpgrade to allow testing
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOperator {}
}

contract C3CallerUpgradesTest is Helpers {
    C3UUIDKeeper c3UUIDKeeper;
    C3CallerUpgradeable public c3callerV1;
    C3CallerUpgradeableV2 public c3callerV2;
    C3CallerUpgradeableV3 public c3callerV3;
    MockC3CallerDApp public mockDApp;

    address public implementationV1;
    address public implementationV2;
    address public implementationV3;
    address public proxy;

    uint256 public testDAppID = 123;

    function setUp() public virtual override {
        super.setUp();

        // Deploy implementations
        implementationV1 = address(new C3CallerUpgradeable());
        implementationV2 = address(new C3CallerUpgradeableV2());
        implementationV3 = address(new C3CallerUpgradeableV3());

        // Deploy C3Caller proxy with V1 implementation

        vm.startPrank(gov);
        address c3UUIDKeeperImpl = address(new C3UUIDKeeperUpgradeable());
        c3UUIDKeeper = C3UUIDKeeper(_deployProxy(c3UUIDKeeperImpl, abi.encodeCall(C3UUIDKeeperUpgradeable.initialize, ())));
        bytes memory initData = abi.encodeCall(
            C3CallerUpgradeable.initialize,
            (address(c3UUIDKeeper))
        );
        proxy = _deployProxy(implementationV1, initData);
        c3callerV1 = C3CallerUpgradeable(proxy);

        // Add operator permissions
        c3UUIDKeeper.addOperator(address(c3callerV1)); // Add C3Caller as operator to C3UUIDKeeper
        c3callerV1.addOperator(gov); // Add gov as an operator to C3Caller
        c3callerV1.addOperator(mpc1); // Add mpc1 as an operator to C3Caller
        vm.stopPrank();

        // Deploy mock dapp
        mockDApp = new MockC3CallerDApp(address(c3callerV1), testDAppID);
    }

    // ============ DEPLOYMENT TESTS ============

    function test_DeployProxy() public view {
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV1);
        assertEq(c3callerV1.gov(), gov);
        assertEq(c3callerV1.uuidKeeper(), address(c3UUIDKeeper));
        assertTrue(c3callerV1.isExecutor(gov));
    }

    function test_InitializationRevertsIfCalledTwice() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        c3callerV1.initialize(address(c3UUIDKeeper));
    }

    function test_ProxyImplementationAddress() public view {
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV1);
    }

    // ============ UPGRADE TESTS ============

    function test_UpgradeToV2() public {
        // Verify initial state
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV1);

        // Upgrade to V2
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );

        // Verify upgrade
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV2);

        // Cast to V2 and test new functionality
        C3CallerUpgradeableV2 c3callerV2Instance = C3CallerUpgradeableV2(proxy);
        c3callerV2Instance.setNewStorageVariable(42);
        assertEq(c3callerV2Instance.getNewStorageVariable(), 42);

        // Verify existing functionality still works
        assertEq(c3callerV2Instance.gov(), gov);
        assertEq(c3callerV2Instance.uuidKeeper(), address(c3UUIDKeeper));
    }

    function test_UpgradeToV3() public {
        // First upgrade to V2
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );

        // Then upgrade to V3
        vm.prank(gov);
        C3CallerUpgradeableV2(proxy).upgradeToAndCall(
            implementationV3,
            abi.encodeCall(C3CallerUpgradeableV3.initializeV3, ())
        );

        // Verify upgrade
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV3);

        // Cast to V3 and test new functionality
        C3CallerUpgradeableV3 c3callerV3Instance = C3CallerUpgradeableV3(proxy);
        c3callerV3Instance.setNewStorageVariable(100);
        c3callerV3Instance.setVersion("3.0.0");

        assertEq(c3callerV3Instance.getNewStorageVariable(), 100);
        assertEq(c3callerV3Instance.getVersion(), "3.0.0");

        // Verify existing functionality still works
        assertEq(c3callerV3Instance.gov(), gov);
        assertEq(c3callerV3Instance.uuidKeeper(), address(c3UUIDKeeper));
    }

    function test_UpgradeAndCall() public {
        // Upgrade to V2 with initialization
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.setNewStorageVariable, (999))
        );

        // Verify upgrade and initialization
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV2);
        C3CallerUpgradeableV2 c3callerV2Instance = C3CallerUpgradeableV2(proxy);
        assertEq(c3callerV2Instance.getNewStorageVariable(), 999);
    }

    // ============ AUTHORIZATION TESTS ============

    function test_UpgradeRevertsIfNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );
    }

    function test_UpgradeAndCallRevertsIfNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.setNewStorageVariable, (999))
        );
    }

    function test_UpgradeByOperator() public {
        // Add user1 as operator
        vm.prank(gov);
        c3callerV1.addOperator(user1);

        // Upgrade by operator
        vm.prank(user1);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );

        // Verify upgrade
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV2);
    }

    // ============ FUNCTIONALITY TESTS AFTER UPGRADE ============

    function test_C3CallAfterUpgrade() public {
        // Upgrade to V2
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );

        // Test c3call functionality after upgrade
        bytes memory data = abi.encodeWithSignature("test()");
        string memory to = "0x1234567890123456789012345678901234567890";
        string memory toChainID = "_toChainID";
        uint256 dappID = 1;

        // Calculate expected UUID
        bytes32 uuid = c3UUIDKeeper.calcCallerUUID(
            address(c3callerV1),
            dappID,
            to,
            toChainID,
            data
        );

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit IC3Caller.LogC3Call(
            dappID, // indexed dappID
            uuid, // indexed uuid
            user1, // caller
            toChainID, // toChainID
            to, // to
            data, // data
            "" // empty extra data
        );

        C3CallerUpgradeableV2(proxy).c3call(dappID, to, toChainID, data);
    }

    function test_StoragePersistenceAfterUpgrade() public {
        // Set some state in V1
        vm.prank(gov);
        c3callerV1.addOperator(user2);

        // Upgrade to V2
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );

        // Verify state persistence
        C3CallerUpgradeableV2 c3callerV2Instance = C3CallerUpgradeableV2(proxy);
        assertTrue(c3callerV2Instance.isExecutor(user2));

        // Set new storage variable
        c3callerV2Instance.setNewStorageVariable(123);
        assertEq(c3callerV2Instance.getNewStorageVariable(), 123);

        // Upgrade to V3
        vm.prank(gov);
        c3callerV2Instance.upgradeToAndCall(
            implementationV3,
            abi.encodeCall(C3CallerUpgradeableV3.initializeV3, ())
        );

        // Verify all state persistence
        C3CallerUpgradeableV3 c3callerV3Instance = C3CallerUpgradeableV3(proxy);
        assertTrue(c3callerV3Instance.isExecutor(user2));
        assertEq(c3callerV3Instance.getNewStorageVariable(), 123);
    }

    // ============ ERROR HANDLING TESTS ============

    function test_UpgradeToInvalidImplementation() public {
        vm.prank(gov);
        vm.expectRevert();
        c3callerV1.upgradeToAndCall(address(0), "");
    }

    function test_UpgradeToSameImplementation() public {
        bytes memory initData = abi.encodeCall(
            C3CallerUpgradeableV2.initializeV2,
            ()
        );
        vm.startPrank(gov);
        c3callerV1.upgradeToAndCall(implementationV2, initData);
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        c3callerV1.upgradeToAndCall(implementationV2, initData);
        vm.stopPrank();
    }

    function test_UpgradeToNonContract() public {
        vm.prank(gov);
        vm.expectRevert();
        c3callerV1.upgradeToAndCall(address(0x1234), "");
    }

    // ============ MULTIPLE UPGRADE SCENARIOS ============

    function test_MultipleUpgrades() public {
        // V1 -> V2
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(implementationV2, "");

        C3CallerUpgradeableV2 c3callerV2Instance = C3CallerUpgradeableV2(proxy);
        c3callerV2Instance.setNewStorageVariable(50);

        // V2 -> V3
        vm.prank(gov);
        c3callerV2Instance.upgradeToAndCall(implementationV3, "");

        C3CallerUpgradeableV3 c3callerV3Instance = C3CallerUpgradeableV3(proxy);
        c3callerV3Instance.setVersion("final");

        // Verify all state
        assertEq(c3callerV3Instance.getNewStorageVariable(), 50);
        assertEq(c3callerV3Instance.getVersion(), "final");
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV3);
    }

    function test_UpgradeWithComplexState() public {
        // Add multiple operators
        vm.startPrank(gov);
        c3callerV1.addOperator(user1);
        c3callerV1.addOperator(user2);
        c3callerV1.addOperator(mpc2);
        vm.stopPrank();

        // Upgrade to V2
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );

        C3CallerUpgradeableV2 c3callerV2Instance = C3CallerUpgradeableV2(proxy);
        c3callerV2Instance.setNewStorageVariable(999);

        // Verify all operators still exist
        assertTrue(c3callerV2Instance.isExecutor(gov));
        assertTrue(c3callerV2Instance.isExecutor(user1));
        assertTrue(c3callerV2Instance.isExecutor(user2));
        assertTrue(c3callerV2Instance.isExecutor(mpc1));
        assertTrue(c3callerV2Instance.isExecutor(mpc2));

        // Upgrade to V3
        vm.prank(gov);
        c3callerV2Instance.upgradeToAndCall(
            implementationV3,
            abi.encodeCall(C3CallerUpgradeableV3.initializeV3, ())
        );

        C3CallerUpgradeableV3 c3callerV3Instance = C3CallerUpgradeableV3(proxy);

        // Verify all state persists
        assertTrue(c3callerV3Instance.isExecutor(gov));
        assertTrue(c3callerV3Instance.isExecutor(user1));
        assertTrue(c3callerV3Instance.isExecutor(user2));
        assertTrue(c3callerV3Instance.isExecutor(mpc1));
        assertTrue(c3callerV3Instance.isExecutor(mpc2));
        assertEq(c3callerV3Instance.getNewStorageVariable(), 999);
    }

    // ============ PROXY SPECIFIC TESTS ============

    function test_ProxyImplementationGetter() public {
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV1);

        // After upgrade
        vm.prank(gov);
        c3callerV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
        );
        assertEq(IC3CallerProxy(proxy).getImplementation(), implementationV2);
    }

    function test_ProxyImplementationSlot() public view {
        // Verify implementation slot
        bytes32 implementationSlot = bytes32(
            uint256(uint160(implementationV1))
        );
        bytes32 slot = bytes32(
            uint256(
                0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
            )
        );
        bytes32 value = vm.load(proxy, slot);
        assertEq(value, implementationSlot);
    }
}
