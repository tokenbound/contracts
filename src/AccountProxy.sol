// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "openzeppelin-contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "openzeppelin-contracts/proxy/Proxy.sol";

import "./interfaces/IAccountGuardian.sol";

contract AccountProxy is Proxy, ERC1967Upgrade {
    IAccountGuardian immutable guardian;

    constructor(address _guardian) {
        guardian = IAccountGuardian(_guardian);
    }

    function initialize() external {
        address implementation = ERC1967Upgrade._getImplementation();

        if (implementation == address(0)) {
            ERC1967Upgrade._upgradeTo(guardian.defaultImplementation());
        }
    }

    function _implementation() internal view override returns (address) {
        return ERC1967Upgrade._getImplementation();
    }
}
