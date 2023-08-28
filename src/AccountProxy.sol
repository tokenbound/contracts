// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

error InvalidImplementation();

contract AccountProxy is Proxy, ERC1967Upgrade {
    address immutable initialImplementation;

    constructor(address _initialImplementation) {
        if (_initialImplementation == address(0)) {
            revert InvalidImplementation();
        }
        initialImplementation = _initialImplementation;
    }

    function initialize() external {
        ERC1967Upgrade._upgradeTo(initialImplementation);
    }

    function _implementation() internal view override returns (address) {
        return ERC1967Upgrade._getImplementation();
    }
}
