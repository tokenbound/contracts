// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

error InvalidImplementation();

contract AccountProxy is Proxy, ERC1967Upgrade {
    address immutable staticImplementation;

    constructor(address _staticImplementation) {
        if (_staticImplementation == address(0)) {
            revert InvalidImplementation();
        }
        staticImplementation = _staticImplementation;
    }

    function _implementation() internal view override returns (address) {
        address implementation = ERC1967Upgrade._getImplementation();

        if (implementation == address(0)) {
            return staticImplementation;
        }

        return implementation;
    }
}
