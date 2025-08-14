# C3 Contract Upgrades Guide

## Overview

This guide explains how to upgrade the C3 protocol contracts using the UUPS (Universal Upgradeable Proxy Standard) pattern with ERC1967 Proxy. The C3 protocol provides upgradeable versions of all major contracts to allow for future improvements and bug fixes while maintaining the same interface and state.

## Upgradeable Contracts

The following contracts have upgradeable versions:

- **C3CallerUpgradeable** - Main cross-chain caller contract
- **C3UUIDKeeperUpgradeable** - UUID management contract
- **C3DAppManagerUpgradeable** - DApp management contract
- **C3GovernorUpgradeable** - Governance contract
- **C3GovernDAppUpgradeable** - Governance DApp contract
- **C3GovClientUpgradeable** - Governance client contract
- **C3CallerDAppUpgradeable** - Caller DApp contract

## Architecture

### UUPS Pattern
The C3 contracts use the UUPS (Universal Upgradeable Proxy Standard) pattern, which:
- Stores the implementation address in a specific storage slot
- Delegates all calls to the implementation contract
- Allows only authorized addresses to upgrade the implementation
- Maintains state in the proxy contract

### ERC1967 Proxy
The `C3CallerProxy` contract extends OpenZeppelin's `ERC1967Proxy` and provides:
- Standard proxy functionality
- Implementation address retrieval
- ETH reception capability

## Initial Deployment

### 1. Deploy Implementation Contracts
```solidity
// Deploy implementation contracts
C3UUIDKeeperUpgradeable c3UUIDKeeperImpl = new C3UUIDKeeperUpgradeable();
C3CallerUpgradeable c3callerImpl = new C3CallerUpgradeable();
C3DAppManagerUpgradeable c3DAppManagerImpl = new C3DAppManagerUpgradeable();
```

### 2. Deploy Proxy Contracts
```solidity
// Deploy C3UUIDKeeper proxy
bytes memory c3UUIDKeeperInitData = abi.encodeWithSignature("initialize()");
address c3UUIDKeeper = address(new C3CallerProxy(
    address(c3UUIDKeeperImpl), 
    c3UUIDKeeperInitData
));

// Deploy C3Caller proxy
bytes memory c3callerInitData = abi.encodeWithSignature(
    "initialize(address)", 
    c3UUIDKeeper
);
address c3caller = address(new C3CallerProxy(
    address(c3callerImpl), 
    c3callerInitData
));

// Deploy C3DAppManager proxy
bytes memory c3DAppManagerInitData = abi.encodeWithSignature("initialize()");
address c3DAppManager = address(new C3CallerProxy(
    address(c3DAppManagerImpl), 
    c3DAppManagerInitData
));
```

## Upgrade Process

### 1. Prepare New Implementation

Create a new implementation contract that extends the current upgradeable contract:

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.27;

import {C3CallerUpgradeable} from "./C3CallerUpgradeable.sol";

contract C3CallerUpgradeableV2 is C3CallerUpgradeable {
    // New storage variable
    uint256 public newFeature;
    
    // New function
    function setNewFeature(uint256 _value) external onlyGov {
        newFeature = _value;
    }
    
    // Override _authorizeUpgrade to control who can upgrade
    function _authorizeUpgrade(address newImplementation) 
        internal 
        virtual 
        override 
        onlyGov 
    {}
}
```

### 2. Deploy New Implementation
```solidity
// Deploy new implementation
C3CallerUpgradeableV2 newImpl = new C3CallerUpgradeableV2();
```

### 3. Execute Upgrade

#### Option A: Simple Upgrade
```solidity
// Upgrade to new implementation
vm.prank(gov);
c3caller.upgradeTo(address(newImpl));
```

#### Option B: Upgrade with Initialization
```solidity
// Upgrade and initialize new features
vm.prank(gov);
c3caller.upgradeToAndCall(
    address(newImpl),
    abi.encodeWithSignature("setNewFeature(uint256)", 42)
);
```

#### Option C: Upgrade with Reinitialization
```solidity
// If the new implementation has reinitializer functions
vm.prank(gov);
c3caller.upgradeToAndCall(
    address(newImpl),
    abi.encodeWithSignature("initializeV2()")
);
```

## Authorization

### Who Can Upgrade
Only authorized addresses can perform upgrades:

- **Governor**: The governance address can always upgrade
- **Operators**: Addresses with operator permissions can upgrade (if configured)

### Authorization Check
The `_authorizeUpgrade` function controls who can upgrade:

```solidity
function _authorizeUpgrade(address newImplementation) 
    internal 
    virtual 
    override 
    onlyGov 
{
    // Custom authorization logic can be added here
}
```

## Storage Layout

### Important Considerations
1. **Storage Slots**: Never change the order of existing storage variables
2. **Gaps**: Use storage gaps for future variables
3. **Inheritance**: Be careful with inheritance to avoid storage conflicts

### Example Storage Layout
```solidity
contract C3CallerUpgradeableV2 is C3CallerUpgradeable {
    // New storage variables (add at the end)
    uint256 public newFeature;
    mapping(address => bool) public newMapping;
    
    // Storage gap for future upgrades
    uint256[50] private __gap;
}
```

## Testing Upgrades

### 1. Deploy Test Setup
```solidity
function setUp() public {
    // Deploy implementations
    implementationV1 = address(new C3CallerUpgradeable());
    implementationV2 = address(new C3CallerUpgradeableV2());
    
    // Deploy proxy with V1
    proxy = _deployProxy(
        implementationV1, 
        abi.encodeCall(C3CallerUpgradeable.initialize, (uuidKeeper))
    );
    c3callerV1 = C3CallerUpgradeable(proxy);
}
```

### 2. Test Upgrade Process
```solidity
function test_UpgradeToV2() public {
    // Verify initial state
    assertEq(getImplementation(proxy), implementationV1);
    
    // Perform upgrade
    vm.prank(gov);
    c3callerV1.upgradeToAndCall(
        implementationV2,
        abi.encodeCall(C3CallerUpgradeableV2.initializeV2, ())
    );
    
    // Verify upgrade
    assertEq(getImplementation(proxy), implementationV2);
    
    // Test new functionality
    C3CallerUpgradeableV2 c3callerV2 = C3CallerUpgradeableV2(proxy);
    c3callerV2.setNewFeature(42);
    assertEq(c3callerV2.newFeature(), 42);
    
    // Verify existing functionality still works
    assertEq(c3callerV2.gov(), gov);
}
```

### 3. Test State Persistence
```solidity
function test_StoragePersistenceAfterUpgrade() public {
    // Set state in V1
    vm.prank(gov);
    c3callerV1.addOperator(user1);
    
    // Upgrade to V2
    vm.prank(gov);
    c3callerV1.upgradeToAndCall(implementationV2, "");
    
    // Verify state persistence
    C3CallerUpgradeableV2 c3callerV2 = C3CallerUpgradeableV2(proxy);
    assertTrue(c3callerV2.isExecutor(user1));
}
```

## Best Practices

### 1. Security
- Always test upgrades on testnets first
- Use timelock contracts for production upgrades
- Implement proper access controls
- Audit new implementations thoroughly

### 2. Storage Management
- Never remove or reorder existing storage variables
- Use storage gaps for future flexibility
- Document storage layout changes
- Test storage compatibility

### 3. Upgrade Process
- Plan upgrades carefully
- Communicate changes to users
- Have rollback plans ready
- Monitor upgrades closely

### 4. Testing
- Test all functionality after upgrades
- Verify state persistence
- Test edge cases and error conditions
- Use comprehensive test suites

## Common Patterns

### 1. Feature Flags
```solidity
contract C3CallerUpgradeableV2 is C3CallerUpgradeable {
    bool public newFeatureEnabled;
    
    function enableNewFeature() external onlyGov {
        newFeatureEnabled = true;
    }
    
    function someFunction() external {
        if (newFeatureEnabled) {
            // New implementation
        } else {
            // Old implementation
        }
    }
}
```

### 2. Gradual Rollouts
```solidity
contract C3CallerUpgradeableV2 is C3CallerUpgradeable {
    mapping(address => bool) public betaUsers;
    
    function addBetaUser(address user) external onlyGov {
        betaUsers[user] = true;
    }
    
    function someFunction() external {
        if (betaUsers[msg.sender]) {
            // New implementation for beta users
        } else {
            // Old implementation for regular users
        }
    }
}
```

### 3. Data Migration
```solidity
contract C3CallerUpgradeableV2 is C3CallerUpgradeable {
    bool public migrationCompleted;
    
    function migrateData() external onlyGov {
        require(!migrationCompleted, "Migration already completed");
        
        // Perform data migration
        // ...
        
        migrationCompleted = true;
    }
}
```

## Troubleshooting

### Common Issues

1. **Initialization Revert**
   - Ensure initialization function is only called once
   - Check that initialization parameters are correct

2. **Storage Conflicts**
   - Verify storage layout compatibility
   - Check for inheritance conflicts

3. **Authorization Failures**
   - Ensure caller has proper permissions
   - Check `_authorizeUpgrade` implementation

4. **Function Not Found**
   - Verify new implementation has all required functions
   - Check function signatures match

### Debug Commands
```solidity
// Get current implementation
address impl = IC3CallerProxy(proxy).getImplementation();

// Check if address is operator
bool isOp = c3caller.isExecutor(address);

// Get governance address
address gov = c3caller.gov();
```

## Emergency Procedures

### 1. Pause Contract
```solidity
// Pause contract if issues are detected
vm.prank(gov);
c3caller.pause();
```

### 2. Rollback Upgrade
```solidity
// Rollback to previous implementation
vm.prank(gov);
c3caller.upgradeTo(previousImplementation);
```

### 3. Emergency Governance
```solidity
// Transfer governance if needed
vm.prank(gov);
c3caller.changeGov(newGovernance);
```

## Conclusion

The C3 protocol's upgradeable contracts provide flexibility for future improvements while maintaining security and state consistency. Always follow best practices, test thoroughly, and have emergency procedures in place before performing upgrades in production.

For more information, refer to the individual contract documentation and test files for specific implementation details.
