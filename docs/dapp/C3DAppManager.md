# C3DAppManager

## Overview

C3DAppManager is a comprehensive contract for managing DApp configurations, fees, and MPC addresses in the C3 protocol. This contract provides centralized management functionality for DApps including configuration, fee management, staking pools, and MPC address management.

### Key Features

- DApp configuration management
- Fee configuration and management
- Staking pool management
- MPC address and public key management
- Blacklist functionality
- Pausable functionality for emergency stops

**Note:** This contract is the central management hub for C3 DApps

## Contract Details

- **Contract Name:** `C3DAppManager`
- **Implements:** `IC3DAppManager`
- **Inherits:** `C3GovClient`, `Pausable`
- **Author:** @potti ContinuumDAO
- **License:** BSL-1.1

## State Variables

### `dappID`
```solidity
uint256 public dappID
```
The DApp identifier for this manager.

### `dappConfig`
```solidity
mapping(uint256 => DAppConfig) private dappConfig
```
Mapping of DApp ID to DApp configuration.

### `c3DAppAddr`
```solidity
mapping(string => uint256) public c3DAppAddr
```
Mapping of DApp address string to DApp ID.

### `appBlacklist`
```solidity
mapping(uint256 => bool) public appBlacklist
```
Mapping of DApp ID to blacklist status.

### `feeCurrencies`
```solidity
mapping(address => uint256) public feeCurrencies
```
Mapping of asset address to fee per byte.

### `dappStakePool`
```solidity
mapping(uint256 => mapping(address => uint256)) public dappStakePool
```
Mapping of DApp ID and token address to staking pool balance.

### `speChainFees`
```solidity
mapping(string => mapping(address => uint256)) public speChainFees
```
Mapping of chain and token address to specific chain fees.

### `fees`
```solidity
mapping(address => uint256) private fees
```
Mapping of token address to accumulated fees.

### `mpcPubkey`
```solidity
mapping(uint256 => mapping(string => string)) public mpcPubkey
```
Mapping of DApp ID and MPC address to public key.

### `mpcAddrs`
```solidity
mapping(uint256 => string[]) public mpcAddrs
```
Mapping of DApp ID to array of MPC addresses.

## Constructor

### `constructor()`
Initializes the C3DAppManager contract.

**Notes:**
- Initializes the contract with the deployer as governor
- C3GovClient constructor handles the initialization

## Modifiers

### `onlyGovOrAdmin(uint256 _dappID)`
Restricts access to governance or DApp admin.

**Parameters:**
- `_dappID` (uint256): The DApp identifier

**Notes:**
- Reverts if the caller is neither governor nor DApp admin

## External Functions

### `pause()`
Pause the contract (governance only).

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function

### `unpause()`
Unpause the contract (governance only).

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function

### `setBlacklists(uint256 _dappID, bool _flag)`
Set blacklist status for a DApp (governance only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_flag` (bool): The blacklist flag

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function

### `setDAppConfig(uint256 _dappID, address _appAdmin, address _feeToken, string memory _appDomain, string memory _email)`
Set DApp configuration (governance only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_appAdmin` (address): The DApp admin address
- `_feeToken` (address): The fee token address
- `_appDomain` (string): The DApp domain
- `_email` (string): The DApp email

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function
- Reverts if fee token is zero or domain/email is empty

### `setDAppAddr(uint256 _dappID, string[] memory _addresses)`
Set DApp addresses (governance or DApp admin only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_addresses` (string[]): Array of DApp addresses

**Modifiers:**
- `onlyGovOrAdmin`

**Notes:**
- Only governance or DApp admin can call this function

### `addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey)`
Add MPC address and public key (governance or DApp admin only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_addr` (string): The MPC address
- `_pubkey` (string): The MPC public key

**Modifiers:**
- `onlyGovOrAdmin`

**Notes:**
- Only governance or DApp admin can call this function
- Reverts if DApp admin is zero, addresses are empty, or lengths don't match

### `delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey)`
Delete MPC address and public key (governance or DApp admin only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_addr` (string): The MPC address to delete
- `_pubkey` (string): The MPC public key to delete

**Modifiers:**
- `onlyGovOrAdmin`

**Notes:**
- Only governance or DApp admin can call this function
- Reverts if DApp admin is zero or addresses are empty

### `setFeeConfig(address _token, string memory _chain, uint256 _callPerByteFee)`
Set fee configuration for a token and chain (governance only).

**Parameters:**
- `_token` (address): The token address
- `_chain` (string): The chain identifier
- `_callPerByteFee` (uint256): The fee per byte

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function
- Reverts if the fee is zero

### `deposit(uint256 _dappID, address _token, uint256 _amount)`
Deposit tokens to a DApp's staking pool.

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_token` (address): The token address
- `_amount` (uint256): The amount to deposit

**Notes:**
- Reverts if the amount is zero

### `withdraw(uint256 _dappID, address _token, uint256 _amount)`
Withdraw tokens from a DApp's staking pool (governance or DApp admin only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_token` (address): The token address
- `_amount` (uint256): The amount to withdraw

**Modifiers:**
- `onlyGovOrAdmin`

**Notes:**
- Only governance or DApp admin can call this function
- Reverts if the amount is zero or insufficient balance

### `charging(uint256 _dappID, address _token, uint256 _bill)`
Charge fees from a DApp's staking pool (governance or DApp admin only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_token` (address): The token address
- `_bill` (uint256): The amount to charge

**Modifiers:**
- `onlyGovOrAdmin`

**Notes:**
- Only governance or DApp admin can call this function
- Reverts if the bill is zero or insufficient balance

### `getDAppConfig(uint256 _dappID)`
Get DApp configuration.

**Parameters:**
- `_dappID` (uint256): The DApp identifier

**Returns:**
- `DAppConfig`: The DApp configuration

### `getMpcAddrs(uint256 _dappID)`
Get MPC addresses for a DApp.

**Parameters:**
- `_dappID` (uint256): The DApp identifier

**Returns:**
- `string[]`: Array of MPC addresses

### `getMpcPubkey(uint256 _dappID, string memory _addr)`
Get MPC public key for a DApp and address.

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_addr` (string): The MPC address

**Returns:**
- `string`: The MPC public key

### `getFeeCurrency(address _token)`
Get fee currency for a token.

**Parameters:**
- `_token` (address): The token address

**Returns:**
- `uint256`: The fee per byte for the token

### `getSpeChainFee(string memory _chain, address _token)`
Get specific chain fee for a token.

**Parameters:**
- `_chain` (string): The chain identifier
- `_token` (address): The token address

**Returns:**
- `uint256`: The fee per byte for the token on the specific chain

### `getDAppStakePool(uint256 _dappID, address _token)`
Get DApp staking pool balance.

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_token` (address): The token address

**Returns:**
- `uint256`: The staking pool balance

### `getFee(address _token)`
Get accumulated fees for a token.

**Parameters:**
- `_token` (address): The token address

**Returns:**
- `uint256`: The accumulated fees

### `setFee(address _token, uint256 _fee)`
Set accumulated fees for a token (governance only).

**Parameters:**
- `_token` (address): The token address
- `_fee` (uint256): The fee amount

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function

### `setDAppID(uint256 _dappID)`
Set the DApp ID for this manager (governance only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier

**Modifiers:**
- `onlyGov`

**Notes:**
- Only the governor can call this function

### `setDAppConfigDiscount(uint256 _dappID, uint256 _discount)`
Set DApp configuration discount (governance or DApp admin only).

**Parameters:**
- `_dappID` (uint256): The DApp identifier
- `_discount` (uint256): The discount amount

**Modifiers:**
- `onlyGovOrAdmin`

**Notes:**
- Only governance or DApp admin can call this function
- Reverts if DApp ID is zero or discount is zero

## Data Structures

### `DAppConfig`
Represents the configuration for a DApp.

```solidity
struct DAppConfig {
    uint256 id;
    address appAdmin; // account who admin the application's config
    address feeToken; // token address for fee token
    uint256 discount; // discount
}
```

**Fields:**
- `id` (uint256): The DApp identifier
- `appAdmin` (address): Account who administers the application's config
- `feeToken` (address): Token address for fee token
- `discount` (uint256): Discount amount

## Events

### `SetDAppConfig`
Emitted when DApp configuration is set.

```solidity
event SetDAppConfig(
    uint256 indexed dappID,
    address indexed appAdmin,
    address indexed feeToken,
    string appDomain,
    string email
);
```

### `SetBlacklists`
Emitted when blacklist status is set.

```solidity
event SetBlacklists(uint256 _dappID, bool _flag);
```

### `SetDAppAddr`
Emitted when DApp addresses are set.

```solidity
event SetDAppAddr(uint256 _dappID, string[] _addresses);
```

### `AddMpcAddr`
Emitted when MPC address is added.

```solidity
event AddMpcAddr(uint256 _dappID, string _addr, string _pubkey);
```

### `DelMpcAddr`
Emitted when MPC address is deleted.

```solidity
event DelMpcAddr(uint256 _dappID, string _addr, string _pubkey);
```

### `SetFeeConfig`
Emitted when fee configuration is set.

```solidity
event SetFeeConfig(address _token, string _chain, uint256 _callPerByteFee);
```

### `Deposit`
Emitted when tokens are deposited to staking pool.

```solidity
event Deposit(uint256 _dappID, address _token, uint256 _amount, uint256 _left);
```

### `Withdraw`
Emitted when tokens are withdrawn from staking pool.

```solidity
event Withdraw(uint256 _dappID, address _token, uint256 _amount, uint256 _left);
```

### `Charging`
Emitted when fees are charged from staking pool.

```solidity
event Charging(uint256 _dappID, address _token, uint256 _bill, uint256 _amount, uint256 _left);
```

## Errors

### `C3DAppManager_IsZero`
Thrown when a required parameter is zero.

```solidity
error C3DAppManager_IsZero(C3ErrorParam);
```

### `C3DAppManager_IsZeroAddress`
Thrown when a required address parameter is zero.

```solidity
error C3DAppManager_IsZeroAddress(C3ErrorParam);
```

### `C3DAppManager_InvalidDAppID`
Thrown when the DApp ID is invalid.

```solidity
error C3DAppManager_InvalidDAppID(uint256);
```

### `C3DAppManager_NotZeroAddress`
Thrown when an address parameter should not be zero.

```solidity
error C3DAppManager_NotZeroAddress(C3ErrorParam);
```

### `C3DAppManager_LengthMismatch`
Thrown when two parameters have mismatched lengths.

```solidity
error C3DAppManager_LengthMismatch(C3ErrorParam, C3ErrorParam);
```

### `C3DAppManager_OnlyAuthorized`
Thrown when an unauthorized address attempts to perform an operation.

```solidity
error C3DAppManager_OnlyAuthorized(C3ErrorParam, C3ErrorParam);
```

### `C3DAppManager_InsufficientBalance`
Thrown when there is insufficient balance for an operation.

```solidity
error C3DAppManager_InsufficientBalance(address _token);
```

## Usage Examples

### Setting Up a DApp Configuration
```solidity
// Set DApp configuration (governance only)
dappManager.setDAppConfig(
    1, // dappID
    0x1234567890123456789012345678901234567890, // appAdmin
    0x0987654321098765432109876543210987654321, // feeToken
    "example.com", // appDomain
    "admin@example.com" // email
);

// Set DApp addresses
string[] memory addresses = new string[](2);
addresses[0] = "0x1234567890123456789012345678901234567890";
addresses[1] = "0x0987654321098765432109876543210987654321";
dappManager.setDAppAddr(1, addresses);
```

### Managing MPC Addresses
```solidity
// Add MPC address and public key
dappManager.addMpcAddr(
    1, // dappID
    "0x1234567890123456789012345678901234567890", // addr
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890" // pubkey
);

// Delete MPC address
dappManager.delMpcAddr(
    1, // dappID
    "0x1234567890123456789012345678901234567890", // addr
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890" // pubkey
);
```

### Managing Fees and Staking
```solidity
// Set fee configuration
dappManager.setFeeConfig(
    0x1234567890123456789012345678901234567890, // token
    "1", // chain
    1000000000000000 // fee per byte
);

// Deposit to staking pool
dappManager.deposit(
    1, // dappID
    0x1234567890123456789012345678901234567890, // token
    1000000000000000000 // amount
);

// Charge fees
dappManager.charging(
    1, // dappID
    0x1234567890123456789012345678901234567890, // token
    1000000000000000 // bill
);
```

## Security Considerations

1. **Access Control**: Only governance or DApp admins can perform administrative functions
2. **Pausability**: The contract can be paused in emergency situations
3. **Balance Validation**: Ensures sufficient balance before withdrawals or charges
4. **Parameter Validation**: Validates all input parameters to prevent invalid operations
5. **MPC Management**: Secure management of MPC addresses and public keys

## Dependencies

- `@openzeppelin/contracts/token/ERC20/IERC20.sol`
- `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol`
- `@openzeppelin/contracts/utils/Pausable.sol`
- `@openzeppelin/contracts/utils/Strings.sol`
- `C3GovClient.sol`
- `C3ErrorParam` from `C3CallerUtils.sol`
- `IC3DAppManager.sol`
