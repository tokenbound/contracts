// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/proxy/Proxy.sol";

import "./VaultRegistry.sol";

contract VaultProxy is Proxy {
    /// @dev Address of VaultRegistry
    VaultRegistry public immutable registry;

    constructor() {
        registry = VaultRegistry(msg.sender);
    }

    function _implementation()
        internal
        view
        virtual
        override
        returns (address)
    {
        return registry.vaultImplementation(address(this));
    }
}
