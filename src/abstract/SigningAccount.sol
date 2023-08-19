// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

import "./SignatureValidator.sol";

abstract contract SigningAccount is IERC1271, SignatureValidator {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue) {
        if (_isValidSignature(hash, signature)) {
            return IERC1271.isValidSignature.selector;
        }

        return bytes4(0);
    }
}
