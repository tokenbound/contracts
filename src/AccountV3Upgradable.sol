// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./AccountV3.sol";

contract AccountV3Upgradable is AccountV3, UUPSUpgradeable {
    constructor(address entryPoint_, address multicallForwarder, address erc6551Registry)
        AccountV3(entryPoint_, multicallForwarder, erc6551Registry)
    {}

    function _authorizeUpgrade(address) internal virtual override {
        _isValidSigner(_msgSender(), "");
    }
}
