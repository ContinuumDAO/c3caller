# C3DAppManager

Contract for managing DApp configurations, fees, and MPC addresses in the C3 protocol. This contract provides comprehensive management functionality for DApps including configuration, fee management, staking pools, and MPC address management.

## Key Features

- DApp configuration management
- Fee configuration and management
- Staking pool management
- MPC address and public key management
- Blacklist functionality
- DApp lifecycle management (Active, Suspended, Deprecated)
- Status-based access control and enforcement
- Pausable functionality for emergency stops

## Constructor

```solidity
constructor()
```

Initializes the contract with the deployer as governance address.

## State Variables

### dappID
```solidity
uint256 public dappID
```
The DApp ID for the DApp manager

### dappConfig
```solidity
mapping(uint256 => DAppConfig) private dappConfig
```
Mapping of DApp ID to DApp configuration (admin, fee token, discount)

### c3DAppAddr
```solidity
mapping(string => uint256) public c3DAppAddr
```
Mapping of DApp address string to DApp ID

### appBlacklist
```solidity
mapping(uint256 => bool) public appBlacklist
```
Mapping of DApp ID to blacklist status

### dappStatus
```solidity
mapping(uint256 => DAppStatus) public dappStatus
```
Mapping of DApp ID to DApp status (Active, Suspended, Deprecated)

### feeCurrencies
```solidity
mapping(address => uint256) public feeCurrencies
```
Mapping of fee token address to fee per byte

### dappStakePool
```solidity
mapping(uint256 => mapping(address => uint256)) public dappStakePool
```
Mapping of DApp ID and token address to staking pool balance

### speChainFees
```solidity
mapping(string => mapping(address => uint256)) public speChainFees
```
Mapping of chain ID string and token address to fee, to inspect other networks' fees

### fees
```solidity
mapping(address => uint256) private fees
```
Mapping of token address to accumulated fees

### mpcPubkey
```solidity
mapping(uint256 => mapping(string => string)) public mpcPubkey
```
Mapping of DApp ID and MPC address to public key

### mpcAddrs
```solidity
mapping(uint256 => string[]) public mpcAddrs
```
Mapping of DApp ID to array of MPC addresses

### mpcMembership
```solidity
mapping(uint256 => mapping(string => bool)) public mpcMembership
```
Mapping of DApp ID and MPC address to membership status

## Modifiers

### onlyGovOrAdmin
```solidity
modifier onlyGovOrAdmin(uint256 _dappID)
```
Modifier to restrict access to governance or DApp admin.

**Parameters:**
- `_dappID`: The DApp ID

**Dev:** Reverts if the caller is neither governance address nor DApp admin

### onlyActiveDApp
```solidity
modifier onlyActiveDApp(uint256 _dappID)
```
Modifier to check DApp status (Active, Suspended, Deprecated).

**Parameters:**
- `_dappID`: The DApp ID

**Dev:** Reverts if DApp is suspended or deprecated

### notDeprecated
```solidity
modifier notDeprecated(uint256 _dappID)
```
Modifier to prevent registration of deprecated DApp IDs.

**Parameters:**
- `_dappID`: The DApp ID

**Dev:** Reverts if DApp ID is deprecated

### nonZeroDAppID
```solidity
modifier nonZeroDAppID(uint256 _dappID)
```
Modifier to ensure DApp ID is non-zero.

**Parameters:**
- `_dappID`: The DApp ID

**Dev:** Reverts if DApp ID is zero

## Functions

### pause
```solidity
function pause() public onlyGov
```
Pause the contract (governance only).

**Dev:** Only the governance address can call this function

### unpause
```solidity
function unpause() public onlyGov
```
Unpause the contract (governance only).

**Dev:** Only the governance address can call this function

### setBlacklists
```solidity
function setBlacklists(uint256 _dappID, bool _flag) external onlyGov nonZeroDAppID(_dappID)
```
Set blacklist status for a DApp (governance only).

**Parameters:**
- `_dappID`: The DApp ID
- `_flag`: The blacklist flag (true or false)

**Dev:** Reverts if DApp ID is zero. Only the governance address can call this function

### setDAppStatus
```solidity
function setDAppStatus(uint256 _dappID, DAppStatus _status, string memory _reason) external onlyGov nonZeroDAppID(_dappID)
```
Set DApp status (Active, Suspended, Deprecated).

**Parameters:**
- `_dappID`: The DApp ID
- `_status`: The new status
- `_reason`: The reason for the status change

**Dev:** Reverts if the status transition is invalid or DApp ID is zero. Only the governance address can call this function

### setDAppConfig
```solidity
function setDAppConfig(
    uint256 _dappID,
    address _appAdmin,
    address _feeToken,
    string memory _appDomain,
    string memory _email
) external onlyGov nonZeroDAppID(_dappID) notDeprecated(_dappID)
```
Set DApp configuration. This is how new C3Caller DApps can be registered.

**Parameters:**
- `_dappID`: The DApp ID
- `_appAdmin`: The DApp admin address
- `_feeToken`: The fee token address
- `_appDomain`: The DApp domain
- `_email`: The DApp email

**Dev:** Reverts if fee token is zero, domain/email is empty, DApp ID is zero, or DApp ID is deprecated. Only the governance address can call this function

### setDAppAddr
```solidity
function setDAppAddr(uint256 _dappID, string[] memory _addresses) external onlyGovOrAdmin(_dappID) nonZeroDAppID(_dappID) onlyActiveDApp(_dappID)
```
Set DApp addresses.

**Parameters:**
- `_dappID`: The DApp ID
- `_addresses`: Array of DApp addresses

**Dev:** This is network-agnostic, therefore all deployed instances using `_dappID` should be included. Reverts if DApp ID is zero or DApp is not active. Only governance or DApp admin can call this function

### addMpcAddr
```solidity
function addMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) nonZeroDAppID(_dappID) onlyActiveDApp(_dappID)
```
Add MPC address and its corresponding public key to a given DApp.

**Parameters:**
- `_dappID`: The DApp ID
- `_addr`: The MPC address (EVM 20-byte address)
- `_pubkey`: The MPC public key (32-byte MPC node public key)

**Dev:** Reverts if DApp ID is zero, DApp admin is zero, addresses are empty, lengths don't match, DApp is not active, or address already exists. Only governance or DApp admin can call this function

### delMpcAddr
```solidity
function delMpcAddr(uint256 _dappID, string memory _addr, string memory _pubkey) external onlyGovOrAdmin(_dappID) nonZeroDAppID(_dappID) onlyActiveDApp(_dappID)
```
Delete MPC address and its corresponding public key for a given DApp.

**Parameters:**
- `_dappID`: The DApp ID
- `_addr`: The MPC address to delete
- `_pubkey`: The MPC public key to delete

**Dev:** Reverts if DApp ID is zero, DApp admin is zero, addresses are empty, DApp is not active, or address not found. Only governance or DApp admin can call this function

### setFeeConfig
```solidity
function setFeeConfig(address _token, string memory _chain, uint256 _callPerByteFee) external onlyGov
```
Set fee configuration for a fee token and network.

**Parameters:**
- `_token`: The fee token address
- `_chain`: The chain ID
- `_callPerByteFee`: The fee per byte

**Dev:** Reverts if the fee is zero. Only the governance address can call this function

### deposit
```solidity
function deposit(uint256 _dappID, address _token, uint256 _amount) external whenNotPaused nonZeroDAppID(_dappID) onlyActiveDApp(_dappID)
```
Deposit tokens to a DApp's staking pool.

**Parameters:**
- `_dappID`: The DApp ID
- `_token`: The token address
- `_amount`: The amount to deposit

**Dev:** Reverts if DApp ID is zero, amount is zero, or DApp is not active

### withdraw
```solidity
function withdraw(uint256 _dappID, address _token, uint256 _amount) external onlyGovOrAdmin(_dappID) nonZeroDAppID(_dappID) whenNotPaused
```
Withdraw tokens from a DApp's staking pool.

**Parameters:**
- `_dappID`: The DApp ID
- `_token`: The token address
- `_amount`: The amount to withdraw

**Dev:** Reverts if DApp ID is zero, amount is zero, or insufficient balance. Only governance or DApp admin can call this function

### charging
```solidity
function charging(uint256 _dappID, address _token, uint256 _bill) external onlyGovOrAdmin(_dappID) nonZeroDAppID(_dappID) whenNotPaused
```
Charge fees from a DApp's staking pool.

**Parameters:**
- `_dappID`: The DApp ID
- `_token`: The token address
- `_bill`: The amount to charge

**Dev:** Reverts if DApp ID is zero, bill is zero, or insufficient balance. Only governance or DApp admin can call this function

### getDAppConfig
```solidity
function getDAppConfig(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (DAppConfig memory)
```
Get DApp configuration (admin, fee token, discount).

**Parameters:**
- `_dappID`: The DApp ID

**Returns:**
- `DAppConfig`: The DApp configuration

**Dev:** Reverts if DApp ID is zero

### getDAppStatus
```solidity
function getDAppStatus(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (DAppStatus)
```
Get DApp status (Active, Suspended, Deprecated).

**Parameters:**
- `_dappID`: The DApp ID

**Returns:**
- `DAppStatus`: The DApp status

**Dev:** Reverts if DApp ID is zero

### getMpcAddrs
```solidity
function getMpcAddrs(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (string[] memory)
```
Get MPC addresses that have been added for a given DApp.

**Parameters:**
- `_dappID`: The DApp ID

**Returns:**
- `string[]`: Array of MPC addresses

**Dev:** Reverts if DApp ID is zero

### getMpcPubkey
```solidity
function getMpcPubkey(uint256 _dappID, string memory _addr) external view nonZeroDAppID(_dappID) returns (string memory)
```
Get MPC public key for a DApp and address.

**Parameters:**
- `_dappID`: The DApp ID
- `_addr`: The MPC address

**Returns:**
- `string`: The MPC public key

**Dev:** Reverts if DApp ID is zero

### isMpcMember
```solidity
function isMpcMember(uint256 _dappID, string memory _addr) external view nonZeroDAppID(_dappID) returns (bool)
```
Check if MPC address is a member of a DApp.

**Parameters:**
- `_dappID`: The DApp ID
- `_addr`: The MPC address

**Returns:**
- `bool`: True if the address is a member

**Dev:** Reverts if DApp ID is zero

### getMpcCount
```solidity
function getMpcCount(uint256 _dappID) external view nonZeroDAppID(_dappID) returns (uint256)
```
Get the number of MPC addresses for a DApp.

**Parameters:**
- `_dappID`: The DApp ID

**Returns:**
- `uint256`: The number of MPC addresses

**Dev:** Reverts if DApp ID is zero

### getFeeCurrency
```solidity
function getFeeCurrency(address _token) external view returns (uint256)
```
Get fee currency for a token (fee per byte).

**Parameters:**
- `_token`: The token address

**Returns:**
- `uint256`: The fee per byte for the token

### getSpeChainFee
```solidity
function getSpeChainFee(string memory _chain, address _token) external view returns (uint256)
```
Get specific network's fee for a token.

**Parameters:**
- `_chain`: The chain ID
- `_token`: The fee token address

**Returns:**
- `uint256`: The fee per byte of the fee token on the specific network

### getDAppStakePool
```solidity
function getDAppStakePool(uint256 _dappID, address _token) external view nonZeroDAppID(_dappID) returns (uint256)
```
Get staking pool balance of a specific DApp.

**Parameters:**
- `_dappID`: The DApp ID
- `_token`: The token address

**Returns:**
- `uint256`: The staking pool balance

**Dev:** Reverts if DApp ID is zero

### getFee
```solidity
function getFee(address _token) external view returns (uint256)
```
Get accumulated fees for a token.

**Parameters:**
- `_token`: The fee token address

**Returns:**
- `uint256`: The accumulated fees

### setFee
```solidity
function setFee(address _token, uint256 _fee) external onlyGov
```
Set accumulated fees for a token.

**Parameters:**
- `_token`: The fee token address
- `_fee`: The fee amount

**Dev:** Only the governance address can call this function

### setDAppID
```solidity
function setDAppID(uint256 _dappID) external onlyGov
```
Set the DApp ID for this manager (governance only).

**Parameters:**
- `_dappID`: The DApp ID

**Dev:** Only the governance address can call this function

### setDAppConfigDiscount
```solidity
function setDAppConfigDiscount(uint256 _dappID, uint256 _discount) external onlyGovOrAdmin(_dappID) nonZeroDAppID(_dappID) onlyActiveDApp(_dappID)
```
Set DApp configuration discount.

**Parameters:**
- `_dappID`: The DApp ID
- `_discount`: The discount amount

**Dev:** Reverts if DApp ID is zero, discount is zero, or DApp is not active. Only governance or DApp admin can call this function

## Internal Functions

### _isValidStatusTransition
```solidity
function _isValidStatusTransition(DAppStatus _from, DAppStatus _to) internal pure returns (bool)
```
Internal function to validate status transitions.

**Parameters:**
- `_from`: The current status
- `_to`: The target status

**Returns:**
- `bool`: True if the transition is valid

**Dev:** Deprecated DApps cannot undergo status change - deprecation is permanent

## Events

### SetBlacklists
```solidity
event SetBlacklists(uint256 indexed dappID, bool flag)
```

### DAppStatusChanged
```solidity
event DAppStatusChanged(uint256 indexed dappID, DAppStatus oldStatus, DAppStatus newStatus, string reason)
```

### SetDAppConfig
```solidity
event SetDAppConfig(uint256 indexed dappID, address appAdmin, address feeToken, string appDomain, string email)
```

### SetDAppAddr
```solidity
event SetDAppAddr(uint256 indexed dappID, string[] addresses)
```

### AddMpcAddr
```solidity
event AddMpcAddr(uint256 indexed dappID, string addr, string pubkey)
```

### DelMpcAddr
```solidity
event DelMpcAddr(uint256 indexed dappID, string addr, string pubkey)
```

### SetFeeConfig
```solidity
event SetFeeConfig(address indexed token, string chain, uint256 callPerByteFee)
```

### Deposit
```solidity
event Deposit(uint256 indexed dappID, address indexed token, uint256 amount, uint256 balance)
```

### Withdraw
```solidity
event Withdraw(uint256 indexed dappID, address indexed token, uint256 amount, uint256 balance)
```

### Charging
```solidity
event Charging(uint256 indexed dappID, address indexed token, uint256 bill, uint256 fee, uint256 balance)
```

## Errors

### C3DAppManager_OnlyAuthorized
```solidity
error C3DAppManager_OnlyAuthorized(C3ErrorParam, C3ErrorParam)
```

### C3DAppManager_DAppSuspended
```solidity
error C3DAppManager_DAppSuspended(uint256)
```

### C3DAppManager_DAppDeprecated
```solidity
error C3DAppManager_DAppDeprecated(uint256)
```

### C3DAppManager_ZeroDAppID
```solidity
error C3DAppManager_ZeroDAppID()
```

### C3DAppManager_InvalidStatusTransition
```solidity
error C3DAppManager_InvalidStatusTransition(DAppStatus, DAppStatus)
```

### C3DAppManager_IsZero
```solidity
error C3DAppManager_IsZero(C3ErrorParam)
```

### C3DAppManager_IsZeroAddress
```solidity
error C3DAppManager_IsZeroAddress(C3ErrorParam)
```

### C3DAppManager_LengthMismatch
```solidity
error C3DAppManager_LengthMismatch(C3ErrorParam, C3ErrorParam)
```

### C3DAppManager_MpcAddressExists
```solidity
error C3DAppManager_MpcAddressExists(string)
```

### C3DAppManager_MpcAddressNotFound
```solidity
error C3DAppManager_MpcAddressNotFound(string)
```

### C3DAppManager_InsufficientBalance
```solidity
error C3DAppManager_InsufficientBalance(address)
```

## Structs

### DAppConfig
```solidity
struct DAppConfig {
    uint256 id;
    address appAdmin;
    address feeToken;
    uint256 discount;
}
```

### DAppStatus
```solidity
enum DAppStatus {
    Active,
    Suspended,
    Deprecated
}
```

## Author

@potti ContinuumDAO

## Dev

This contract is the central management hub for C3 DApps