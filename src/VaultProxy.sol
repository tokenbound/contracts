// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Proxy.sol";

import "./VaultRegistry.sol";

contract VaultProxy is Proxy {
    /**
     * @dev Address of VaultRegistry
     */
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
        console.log(address(this));
        return registry.vaultImplementation(address(this));
    }
}
