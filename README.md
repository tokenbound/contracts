# Tokenbound Account Contracts

This repository contains an opinionated [ERC-6551](https://eips.ethereum.org/EIPS/eip-6551) account implementation. The smart contracts are written in Solidity using the [Foundry](https://book.getfoundry.sh/) development framework.

**This project is under active development and may undergo changes until ERC-6551 is finalized.** For the most recently deployed version of these contracts, see the [v0.3.0](https://github.com/tokenbound/contracts/releases/tag/v0.3.0) release. We recommend this version for any production usage.

## Contracts

The `src/` directory contains the main contracts for the project:

- `Account.sol`: This contract is the main ERC-6551 account implementation. It includes functionalities for executing a low-level call against an account if the caller is authorized to make calls, setting the implementation address for a given function call, granting a given caller execution permissions, locking the account until a certain timestamp, and more.

- `AccountGuardian.sol`: This contract manages upgrade and cross-chain execution settings for accounts. It includes functionalities for setting trusted implementations and executors.

- `AccountProxy.sol`: This contract is an ERC-1967 proxy which enables account upgradability. It includes functionalities for initializing and getting the implementation of the contract.

## Using as a Dependency

If you want to use `tokenbound/contracts` as a dependency in another project, you can add it using `forge install`:

```sh
forge install tokenbound=tokenbound/contracts
```

This will add `tokenbound/contracts` as a git submodule in your project. For more information on managing dependencies, refer to the [Foundry dependencies guide](https://github.com/foundry-rs/book/blob/master/src/projects/dependencies.md).

## Development Setup

You will need to have Foundry installed on your system. Please refer to the [Foundry installation guide](https://github.com/foundry-rs/book/blob/master/src/getting-started/installation.md) for detailed instructions.

To use this repository, first clone it:

```sh
git clone https://github.com/tokenbound/contracts.git
cd contracts
```

Then, install the dependencies:

```sh
forge install
```

This will install the submodule dependencies that are in the project.

## Running Tests

To run the tests, use the `forge test` command:

```sh
forge test
```

For more information on writing and running tests, refer to the [Foundry testing guide](https://github.com/foundry-rs/book/blob/master/src/forge/writing-tests.md).

## Contributing

Contributions are welcome and appreciated! Please make sure to run the tests before submitting a pull request.
