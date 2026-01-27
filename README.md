# C3Caller

[![Solidity](https://img.shields.io/badge/solidity-v0.8.27-%23363636?style=for-the-badge&logo=solidity)](https://soliditylang.org)
[![OpenZeppelin](https://img.shields.io/badge/openzeppelin-v5.4.0-%234e5ee4?style=for-the-badge&logo=openzeppelin)](https://docs.openzeppelin.com/contracts/5.x)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-ff3366?style=for-the-badge&logo=foundry)](https://github.com/foundry-rs/foundry)
[![Audit](https://img.shields.io/badge/audit-In%20Progress-yellow?style=for-the-badge)](https://github.com/ContinuumDAO/vectm/tree/main/audits)

## Continuum Cross-Chain Caller

A smart contract suite for arbitrary execution of data across
cross-chain DApps using the ContinuumDAO MPC network.

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

- :pushpin: Version: The schema version, currently version 1.
- :label: Name: The protocol name for this DApp ID. This can be the contract name or the broader ecosystem if it consists of multiple contracts.
- :information_source: Description: An optional short description of the DApp.
- :email: Email: An email address that will be used to notify the DApp admin when their fee reserves are running low or if their fee token will soon be deprecated.
- :link: URL: A custom URL for the protocol for integration with the C3Caller Hub.

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

> [!CAUTION]
> If a different account **or** a different DApp key is used to register the DApp on another network, it will have a different DApp ID and therefore will not be able to communicate with other networks.

**Optional:** If you have a specific subset of MPC addresses that your wish to exclusively allow to execute methods implementing `onlyC3Caller` in your DApp, specify them using `addMPCAddr` in `C3DAppManager` for each relevant network. Otherwise, the entire public pool of MPC addresses will be deemed as valid executors.

### Development

Once a DApp has been registered and a DApp ID obtained, an implementation of `C3CallerDApp` can be deployed. Implementation constructors require:

1. The address of the local `C3Caller` contract on that network,
2. The registered DApp ID.

Note that in order for contracts to be able to communicate across networks, they must implement the same DApp ID.

Once the DApp has been deployed to each network (using the same DApp ID for each deployment), the deployed contracts must be whitelisted by the DApp admin.
To do this, `setDAppAddr` must be called on each network using the local instance of the DApp as input.

*And that's it*. Your contract is now an integrated part of the ContinuumDAO ecoysystem.

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

1. `C3CallerDApp`: basic inheritable DApp
2. `C3GovernDApp`: Same as the basic format, with the addition of an `gov` account that has administrator privileges

# Example Integration

Examples of fully integrated C3Caller DApps can be seen in:

1. C3Governor: a protocol for broadcasting OZ Governor decisions from one network to other networks.
2. CTMERC20: an implementation of ERC20 that burns tokens on a source chain and mints them on a destination chain, enabling chain-agnostic cross-chain transfers.
