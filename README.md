# C3Caller

## Continuum Cross-Chain Caller

A smart contract suite for arbitrary execution of data across
cross-chain DApps using the ContinuumDAO MPC network.

---

## Usage

### Deployment

Protocol contracts are deployed to every supported network. These contracts include:

- `C3Caller`: Main entry point for incoming and outgoing transactions. Communicates directly with the Continuum network via events. Only the MPC network can execute incoming transactions.
- `C3UUIDKeeper`: Tracks UUIDs for each cross-chain transaction and its completion progress/status.
- `C3DAppManager`: Central point to register new DApps on each network and configure their deployed addresses and fee model.

### Fee Model

Network fees are charged for payload size and to cover execution gas cost. The rates are measured as follows:

- Payload: A network fee is charged per byte of calldata on outgoing transactions. This means a minimum of 4 bytes are billable per transaction.
- Gas: A network fee is charged per ether of gas required to execute incoming transactions. A slight excess of the actual gas cost is charged.

Valid fee tokens for each network can be inspected on the `C3DAppManager` contract. Expect lower rates for stablecoins and the protocol token, CTM.

### Metadata

DApp project metadata should be encoded according to the following JSON schema:

```json
{
  "version": 1,
  "name": "CTMRWA1X",
  "description": "AssetX: Cross-chain transfers",
  "email": "admin@assetx.com",
  "url": "assetx.org"
}
```

Version: The schema version, currently version 1.
Name: The protocol name for this DApp ID. This can be the contract name or the broader ecosystem if it consists of multiple contracts.
Description: An optional short description of the DApp.
Email: An email address that will be used to notify the DApp admin when their fee reserves are running low or if their fee token will soon be deprecated.
URL: A custom URL for the protocol for integration with the C3Caller Hub.

### Registration

New DApps can be registered with the locally deployed instance of `C3DAppManager` on supported networks.
Registration involves three main decisions:

1. Decide on a unique DApp key for your project. DApp keys are used to generate the DApp ID (for deterministic derivation on sister networks).
DApp keys should take the form of `vX.contractname.protocolname`, but any consistent naming mechanism that is memorable and modular is valid.
2. Choose a fee token from the list of valid fee tokens. This is what fees will be paid in.
3. Encode DApp metadata according to the [Metadata schema](#metadata). This is optional and improves compatibility with the C3Caller Hub.

*Note:* To prevent spam, `initDAppConfig` takes an initial fee deposit corresponding to the minimum deposit for that fee token. This deposit will be used to pay for DApp fees and can be withdrawn later.

At this point, registration should be done on every network desired for communication, *using the same creator address and DApp key*.
More networks can be added at a later date.

**Optional:** If you have a specific subset of MPC addresses that your wish to exclusively allow to execute methods implementing `onlyC3Caller` in your DApp, specify them using `addMPCAddr` in `C3DAppManager` for each relevant network. Otherwise, the entire public pool of MPC addresses will be deemed as valid executors.

### Development

Once a DApp has been registered and a DApp ID obtained, an implementation of `C3CallerDApp` can be deployed. Implementation constructors require:

1. The address of the local `C3Caller` contract on that network,
2. The registered DApp ID.

Note that in order for contracts to be able to communicate across networks, they must implement the same DApp ID.

Once the DApp has been deployed to each network (using the same DApp ID for each deployment), the deployed contracts must be whitelisted by the DApp admin.
To do this, `setDAppAddr` must be called on each network using the local instance of the DApp as input.

*And that's it*. Your contract is now an integrated part of the ContinuumDAO ecoysystem.

---

# Installation

## Dependencies

Install C3Caller as a dependency to access the smart contracts and implement a `C3CallerDApp`.

### Forge & Soldeer

```bash
forge soldeer install @c3caller~0.1
```

### Forge & Git Submodules

```bash
forge install ContinuumDAO/c3caller
```

### Suggested Remappings (if not using Soldeer)

Example entry in `remappings.txt`:

```
@c3caller/=lib/c3caller/src/
```

## Available Configurations Out of the Box

There are two main valid DApp implementations available out of the box:

1. C3CallerDApp: basic inheritable DApp
2. C3GovernDApp: Same as the basic format, with the addition of an `gov` account that has administrator privileges

---

# Example Integration

Below is an example of a valid implementation of `C3CallerDApp`, where `_c3call` is used to transmit outgoing messages and functions corresponding to incoming messages are marked as `onlyC3Caller`.
Inherit from `C3CallerDApp` and implement the required functions to make it C3Caller compliant:

```solidity
import { C3CallerDApp } from "@c3caller/dapp/C3CallerDApp.sol";

contract MyDApp is C3CallerDApp {

    error CrossChainTransferFailed();

    // The address of the corresponding contract on another chain that will be in communication with this one.
    // It is a string type to accommodate networks that use some other form of account, other than 20-byte hex.
    mapping (string => string) public peers;

    mapping (address => bool) public isMPC;
    mapping (address => uint256) public failedTransfer;

    // Here, we initialize the DApp. Initialize C3CallerDApp with the c3caller endpoint and your DApp ID.
    constructor (address _endpoint, uint256 _dappID, address _mpc, string[] memory _chainIDs, string[] memory _peers)
        C3CallerDApp(_endpoint, _dappID)
    {
        isMPC[_mpc] = true;

        // Here tell this contract the addresses of the contracts that are deployed on other networks that we wish to
        // communicate with via c3caller.
        for (uint8 i = 0; i < _chainIDs.length; i++) {
            peers[_chainIDs[i]] = _peers[i];
        }
    }

    // Override this function to decide what happens when a cross-chain call reverted on the target network.
    // In this example, we check for a known error on the target network and act accordingly.
    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        virtual
        override
        returns (bool)
    {
        if (_selector == CrossChainTransferFailed.selector) {
            (address _recipient, uint256 _amount) = abi.decode(_data, (address, uint256));
            // A cross-chain transfer has failed. Compensate the would-be recipient locally
            failedTransfer[_recipient] += _amount;
        }
        return true;
    }

    // Here we have a function that initiates a cross-chain call. It provides the address of the contract on the
    // target network, based on the given chain ID.
    function transferCrossChain(string memory _targetChainID, address _recipient, uint256 _amount) external {
        bytes memory _data = abi.encodeWithSignature("receiveCrossChain(address,uint256)", (_recipient, _amount));
        string memory _targetNetworkDAppAddress = peers[_targetChainID];
        _c3call(_targetNetworkDAppAddress, _chainID, _data);
    }

    // This function can be executed by `transferCrossChain` that was called from another network.
    // Note the `onlyC3Caller` modifier to ensure only the C3Caller contract (and thus the MPC network) can call this.
    function receiveCrossChain(address _recipient, uint256 _amount) external onlyC3Caller {
        tokenXYZ.transfer(_recipient, _amount);
    }
}
```
