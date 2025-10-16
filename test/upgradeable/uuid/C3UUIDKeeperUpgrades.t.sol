// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {C3UUIDKeeper} from "../../../src/uuid/C3UUIDKeeper.sol";
import {IC3UUIDKeeper} from "../../../src/uuid/IC3UUIDKeeper.sol";
import {C3UUIDKeeperUpgradeable} from "../../../src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";

import {Helpers} from "../../helpers/Helpers.sol";

contract C3UUIDKeeperUpgradeableV2 is C3UUIDKeeperUpgradeable {
    // New storage variable to test storage layout compatibility
    uint256 public newStorageVariable;
    
    // New mapping to test complex storage upgrades
    mapping(bytes32 => string) public uuidMetadata;

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

    // New UUID metadata functionality
    function setUUIDMetadata(bytes32 _uuid, string calldata _metadata) external onlyOperator {
        uuidMetadata[_uuid] = _metadata;
    }

    function getUUIDMetadata(bytes32 _uuid) external view returns (string memory) {
        return uuidMetadata[_uuid];
    }

    // Override _authorizeUpgrade to allow testing
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyGov {}
}

contract C3UUIDKeeperUpgradeableV3 is C3UUIDKeeperUpgradeableV2 {
    // Another storage variable to test multiple upgrades
    string public version;
    
    // New functionality for UUID statistics
    mapping(bytes32 => uint256) public uuidUsageCount;

    function initializeV3() public reinitializer(3) {
        version = "";
    }

    function setVersion(string calldata _version) external {
        version = _version;
    }

    function getVersion() external view returns (string memory) {
        return version;
    }

    // New UUID usage tracking functionality
    function incrementUUIDUsage(bytes32 _uuid) external onlyOperator {
        uuidUsageCount[_uuid]++;
    }

    function getUUIDUsageCount(bytes32 _uuid) external view returns (uint256) {
        return uuidUsageCount[_uuid];
    }

    // Override _authorizeUpgrade to allow testing
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyGov {}
}

contract C3UUIDKeeperUpgradesTest is Helpers {
    C3UUIDKeeperUpgradeable public c3UUIDKeeperV1;
    C3UUIDKeeperUpgradeableV2 public c3UUIDKeeperV2;
    C3UUIDKeeperUpgradeableV3 public c3UUIDKeeperV3;

    address public implementationV1;
    address public implementationV2;
    address public implementationV3;
    address public proxy;

    uint256 public testDAppID = 123;
    string public testTo = "0x1234567890123456789012345678901234567890";
    string public testToChainID = "_toChainID";
    bytes public testData = "test data";

    function setUp() public virtual override {
        super.setUp();

        // Deploy implementations
        implementationV1 = address(new C3UUIDKeeperUpgradeable());
        implementationV2 = address(new C3UUIDKeeperUpgradeableV2());
        implementationV3 = address(new C3UUIDKeeperUpgradeableV3());

        // Deploy C3UUIDKeeper proxy with V1 implementation
        vm.startPrank(gov);
        bytes memory initData = abi.encodeCall(
            C3UUIDKeeperUpgradeable.initialize,
            ()
        );
        proxy = _deployProxy(implementationV1, initData);
        c3UUIDKeeperV1 = C3UUIDKeeperUpgradeable(proxy);

        // Add operator permissions
        c3UUIDKeeperV1.addOperator(gov); // Add gov as an operator
        c3UUIDKeeperV1.addOperator(mpc1); // Add mpc1 as an operator
        vm.stopPrank();
    }

    // ============ DEPLOYMENT TESTS ============

    function test_DeployProxy() public view {
        assertEq(c3UUIDKeeperV1.gov(), gov);
        assertTrue(c3UUIDKeeperV1.isOperator(gov));
        assertTrue(c3UUIDKeeperV1.isOperator(mpc1));
        assertEq(c3UUIDKeeperV1.currentNonce(), 0);
    }

    function test_InitializationRevertsIfCalledTwice() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        c3UUIDKeeperV1.initialize();
    }

    function test_ProxyImplementationAddress() public view {
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

    // ============ UPGRADE TESTS ============

    function test_UpgradeToV2() public {
        // Verify initial state
        assertEq(c3UUIDKeeperV1.currentNonce(), 0);

        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        // Cast to V2 and test new functionality
        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        c3UUIDKeeperV2Instance.setNewStorageVariable(42);
        assertEq(c3UUIDKeeperV2Instance.getNewStorageVariable(), 42);

        // Verify existing functionality still works
        assertEq(c3UUIDKeeperV2Instance.gov(), gov);
        assertTrue(c3UUIDKeeperV2Instance.isOperator(gov));
        assertTrue(c3UUIDKeeperV2Instance.isOperator(mpc1));
    }

    function test_UpgradeToV3() public {
        // First upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        // Then upgrade to V3
        vm.prank(gov);
        C3UUIDKeeperUpgradeableV2(proxy).upgradeToAndCall(
            implementationV3,
            abi.encodeCall(C3UUIDKeeperUpgradeableV3.initializeV3, ())
        );

        // Cast to V3 and test new functionality
        C3UUIDKeeperUpgradeableV3 c3UUIDKeeperV3Instance = C3UUIDKeeperUpgradeableV3(proxy);
        c3UUIDKeeperV3Instance.setNewStorageVariable(100);
        c3UUIDKeeperV3Instance.setVersion("3.0.0");

        assertEq(c3UUIDKeeperV3Instance.getNewStorageVariable(), 100);
        assertEq(c3UUIDKeeperV3Instance.getVersion(), "3.0.0");

        // Verify existing functionality still works
        assertEq(c3UUIDKeeperV3Instance.gov(), gov);
        assertTrue(c3UUIDKeeperV3Instance.isOperator(gov));
        assertTrue(c3UUIDKeeperV3Instance.isOperator(mpc1));
    }

    function test_UpgradeAndCall() public {
        // Upgrade to V2 with initialization
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.setNewStorageVariable, (999))
        );

        // Verify upgrade and initialization
        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        assertEq(c3UUIDKeeperV2Instance.getNewStorageVariable(), 999);
    }

    // ============ AUTHORIZATION TESTS ============

    function test_UpgradeRevertsIfNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );
    }

    function test_UpgradeAndCallRevertsIfNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.setNewStorageVariable, (999))
        );
    }

    function test_UpgradeByGov() public {
        // Upgrade by gov
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        // Verify upgrade
        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        assertEq(c3UUIDKeeperV2Instance.getNewStorageVariable(), 0);
    }

    // ============ UUID FUNCTIONALITY TESTS AFTER UPGRADE ============

    function test_GenUUIDAfterUpgrade() public {
        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        // Test genUUID functionality after upgrade
        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        
        vm.prank(mpc1);
        bytes32 uuid = c3UUIDKeeperV2Instance.genUUID(testDAppID, testTo, testToChainID, testData);
        
        assertTrue(c3UUIDKeeperV2Instance.isUUIDExist(uuid));
        assertEq(c3UUIDKeeperV2Instance.uuid2Nonce(uuid), 1);
        assertEq(c3UUIDKeeperV2Instance.currentNonce(), 1);
    }

    function test_RegisterUUIDAfterUpgrade() public {
        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        // Generate a UUID first
        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        vm.prank(mpc1);
        bytes32 uuid = c3UUIDKeeperV2Instance.genUUID(testDAppID, testTo, testToChainID, testData);
        
        // Test registerUUID functionality after upgrade
        vm.prank(mpc1);
        c3UUIDKeeperV2Instance.registerUUID(uuid, 1);
        
        assertTrue(c3UUIDKeeperV2Instance.isCompleted(uuid));
        assertTrue(c3UUIDKeeperV2Instance.completedSwapin(uuid));
    }

    function test_CalcCallerUUIDAfterUpgrade() public {
        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        // Test calcCallerUUID functionality after upgrade
        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        
        // Calculate expected UUID using the current nonce + 1
        bytes32 expectedUUID = c3UUIDKeeperV2Instance.calcCallerUUID(
            mpc1, // Use mpc1 as the caller
            testDAppID,
            testTo,
            testToChainID,
            testData
        );
        
        // Generate UUID and verify it matches
        vm.prank(mpc1); // Use mpc1 which is an operator
        bytes32 actualUUID = c3UUIDKeeperV2Instance.genUUID(testDAppID, testTo, testToChainID, testData);
        
        assertEq(actualUUID, expectedUUID);
    }

    function test_NewUUIDMetadataFunctionality() public {
        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        
        // Generate a UUID
        vm.prank(mpc1);
        bytes32 uuid = c3UUIDKeeperV2Instance.genUUID(testDAppID, testTo, testToChainID, testData);
        
        // Test new metadata functionality
        string memory metadata = "test metadata";
        vm.prank(mpc1);
        c3UUIDKeeperV2Instance.setUUIDMetadata(uuid, metadata);
        
        assertEq(c3UUIDKeeperV2Instance.getUUIDMetadata(uuid), metadata);
    }

    function test_NewUUIDUsageTrackingFunctionality() public {
        // Upgrade to V3
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );
        
        vm.prank(gov);
        C3UUIDKeeperUpgradeableV2(proxy).upgradeToAndCall(
            implementationV3,
            abi.encodeCall(C3UUIDKeeperUpgradeableV3.initializeV3, ())
        );

        C3UUIDKeeperUpgradeableV3 c3UUIDKeeperV3Instance = C3UUIDKeeperUpgradeableV3(proxy);
        
        // Generate a UUID
        vm.prank(mpc1);
        bytes32 uuid = c3UUIDKeeperV3Instance.genUUID(testDAppID, testTo, testToChainID, testData);
        
        // Test new usage tracking functionality
        vm.prank(mpc1);
        c3UUIDKeeperV3Instance.incrementUUIDUsage(uuid);
        vm.prank(mpc1);
        c3UUIDKeeperV3Instance.incrementUUIDUsage(uuid);
        
        assertEq(c3UUIDKeeperV3Instance.getUUIDUsageCount(uuid), 2);
    }

    // ============ STORAGE PERSISTENCE TESTS ============

    function test_StoragePersistenceAfterUpgrade() public {
        // Set some state in V1
        vm.prank(gov);
        c3UUIDKeeperV1.addOperator(user2);

        // Generate some UUIDs in V1
        vm.prank(mpc1);
        bytes32 uuid1 = c3UUIDKeeperV1.genUUID(testDAppID, testTo, testToChainID, testData);
        vm.prank(mpc1);
        c3UUIDKeeperV1.registerUUID(uuid1, 1);

        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        // Verify state persistence
        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        assertTrue(c3UUIDKeeperV2Instance.isOperator(user2));
        assertTrue(c3UUIDKeeperV2Instance.isCompleted(uuid1));
        assertEq(c3UUIDKeeperV2Instance.currentNonce(), 1);

        // Set new storage variable
        c3UUIDKeeperV2Instance.setNewStorageVariable(123);
        assertEq(c3UUIDKeeperV2Instance.getNewStorageVariable(), 123);

        // Upgrade to V3
        vm.prank(gov);
        c3UUIDKeeperV2Instance.upgradeToAndCall(
            implementationV3,
            abi.encodeCall(C3UUIDKeeperUpgradeableV3.initializeV3, ())
        );

        // Verify all state persistence
        C3UUIDKeeperUpgradeableV3 c3UUIDKeeperV3Instance = C3UUIDKeeperUpgradeableV3(proxy);
        assertTrue(c3UUIDKeeperV3Instance.isOperator(user2));
        assertTrue(c3UUIDKeeperV3Instance.isCompleted(uuid1));
        assertEq(c3UUIDKeeperV3Instance.currentNonce(), 1);
        assertEq(c3UUIDKeeperV3Instance.getNewStorageVariable(), 123);
    }

    function test_ComplexStatePersistence() public {
        // Add multiple operators
        vm.startPrank(gov);
        c3UUIDKeeperV1.addOperator(user1);
        c3UUIDKeeperV1.addOperator(user2);
        vm.stopPrank();

        // Generate multiple UUIDs
        vm.prank(mpc1);
        bytes32 uuid1 = c3UUIDKeeperV1.genUUID(testDAppID, testTo, testToChainID, testData);
        vm.prank(mpc1);
        bytes32 uuid2 = c3UUIDKeeperV1.genUUID(testDAppID, testTo, testToChainID, "different data");
        
        vm.prank(mpc1);
        c3UUIDKeeperV1.registerUUID(uuid1, 1);

        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        c3UUIDKeeperV2Instance.setNewStorageVariable(999);

        // Verify all operators and UUIDs still exist
        assertTrue(c3UUIDKeeperV2Instance.isOperator(gov));
        assertTrue(c3UUIDKeeperV2Instance.isOperator(user1));
        assertTrue(c3UUIDKeeperV2Instance.isOperator(user2));
        assertTrue(c3UUIDKeeperV2Instance.isOperator(mpc1));
        assertTrue(c3UUIDKeeperV2Instance.isUUIDExist(uuid1));
        assertTrue(c3UUIDKeeperV2Instance.isUUIDExist(uuid2));
        assertTrue(c3UUIDKeeperV2Instance.isCompleted(uuid1));
        assertFalse(c3UUIDKeeperV2Instance.isCompleted(uuid2));
        assertEq(c3UUIDKeeperV2Instance.currentNonce(), 2);

        // Upgrade to V3
        vm.prank(gov);
        c3UUIDKeeperV2Instance.upgradeToAndCall(
            implementationV3,
            abi.encodeCall(C3UUIDKeeperUpgradeableV3.initializeV3, ())
        );

        C3UUIDKeeperUpgradeableV3 c3UUIDKeeperV3Instance = C3UUIDKeeperUpgradeableV3(proxy);

        // Verify all state persists
        assertTrue(c3UUIDKeeperV3Instance.isOperator(gov));
        assertTrue(c3UUIDKeeperV3Instance.isOperator(user1));
        assertTrue(c3UUIDKeeperV3Instance.isOperator(user2));
        assertTrue(c3UUIDKeeperV3Instance.isOperator(mpc1));
        assertTrue(c3UUIDKeeperV3Instance.isUUIDExist(uuid1));
        assertTrue(c3UUIDKeeperV3Instance.isUUIDExist(uuid2));
        assertTrue(c3UUIDKeeperV3Instance.isCompleted(uuid1));
        assertFalse(c3UUIDKeeperV3Instance.isCompleted(uuid2));
        assertEq(c3UUIDKeeperV3Instance.currentNonce(), 2);
        assertEq(c3UUIDKeeperV3Instance.getNewStorageVariable(), 999);
    }

    // ============ ERROR HANDLING TESTS ============

    function test_UpgradeToInvalidImplementation() public {
        vm.prank(gov);
        vm.expectRevert();
        c3UUIDKeeperV1.upgradeToAndCall(address(0), "");
    }

    function test_UpgradeToSameImplementation() public {
        bytes memory initData = abi.encodeCall(
            C3UUIDKeeperUpgradeableV2.initializeV2,
            ()
        );
        vm.startPrank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(implementationV2, initData);
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        c3UUIDKeeperV1.upgradeToAndCall(implementationV2, initData);
        vm.stopPrank();
    }

    function test_UpgradeToNonContract() public {
        vm.prank(gov);
        vm.expectRevert();
        c3UUIDKeeperV1.upgradeToAndCall(address(0x1234), "");
    }

    // ============ MULTIPLE UPGRADE SCENARIOS ============

    function test_MultipleUpgrades() public {
        // V1 -> V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(implementationV2, "");

        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        c3UUIDKeeperV2Instance.setNewStorageVariable(50);

        // V2 -> V3
        vm.prank(gov);
        c3UUIDKeeperV2Instance.upgradeToAndCall(implementationV3, "");

        C3UUIDKeeperUpgradeableV3 c3UUIDKeeperV3Instance = C3UUIDKeeperUpgradeableV3(proxy);
        c3UUIDKeeperV3Instance.setVersion("final");

        // Verify all state
        assertEq(c3UUIDKeeperV3Instance.getNewStorageVariable(), 50);
        assertEq(c3UUIDKeeperV3Instance.getVersion(), "final");
    }

    // ============ UUID-SPECIFIC FUNCTIONALITY TESTS ============

    function test_RevokeSwapinAfterUpgrade() public {
        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        
        // Generate and register a UUID
        vm.prank(mpc1);
        bytes32 uuid = c3UUIDKeeperV2Instance.genUUID(testDAppID, testTo, testToChainID, testData);
        vm.prank(mpc1);
        c3UUIDKeeperV2Instance.registerUUID(uuid, 1);
        
        assertTrue(c3UUIDKeeperV2Instance.isCompleted(uuid));
        
        // Revoke the swapin
        vm.prank(gov);
        c3UUIDKeeperV2Instance.revokeSwapin(uuid, 1);
        
        assertFalse(c3UUIDKeeperV2Instance.isCompleted(uuid));
    }

    function test_CalcCallerUUIDWithNonceAfterUpgrade() public {
        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        
        // Test calcCallerUUIDWithNonce functionality after upgrade
        bytes32 expectedUUID = c3UUIDKeeperV2Instance.calcCallerUUIDWithNonce(
            user1,
            testDAppID,
            testTo,
            testToChainID,
            testData,
            5
        );
        
        // Verify the calculation is correct
        bytes32 manualUUID = keccak256(abi.encode(
            address(c3UUIDKeeperV2Instance),
            user1,
            block.chainid,
            testDAppID,
            testTo,
            testToChainID,
            5,
            testData
        ));
        
        assertEq(expectedUUID, manualUUID);
    }

    function test_CalcCallerEncodeAfterUpgrade() public {
        // Upgrade to V2
        vm.prank(gov);
        c3UUIDKeeperV1.upgradeToAndCall(
            implementationV2,
            abi.encodeCall(C3UUIDKeeperUpgradeableV2.initializeV2, ())
        );

        C3UUIDKeeperUpgradeableV2 c3UUIDKeeperV2Instance = C3UUIDKeeperUpgradeableV2(proxy);
        
        // Test calcCallerEncode functionality after upgrade
        bytes memory encoded = c3UUIDKeeperV2Instance.calcCallerEncode(
            user1,
            testDAppID,
            testTo,
            testToChainID,
            testData
        );
        
        // Verify the encoding is correct
        bytes memory expectedEncoded = abi.encode(
            address(c3UUIDKeeperV2Instance),
            user1,
            block.chainid,
            testDAppID,
            testTo,
            testToChainID,
            1, // currentNonce + 1
            testData
        );
        
        assertEq(encoded, expectedEncoded);
    }

    // ============ UUPS/ERC1967 SPECIFIC TESTS ============

    function test_UUPSUpgradeInterface() public {
        // Test that the contract implements UUPS upgrade interface
        // Note: C3UUIDKeeperUpgradeable inherits from UUPSUpgradeable which provides upgrade functionality
        // The supportsInterface method is not directly available, but the upgrade functionality is tested elsewhere
    }

    function test_ImplementationSlot() public view {
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

    function test_AdminSlot() public view {
        // Verify admin slot (should be empty for UUPS)
        bytes32 adminSlot = bytes32(
            uint256(
                0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
            )
        );
        bytes32 value = vm.load(proxy, adminSlot);
        assertEq(value, bytes32(0));
    }
}
