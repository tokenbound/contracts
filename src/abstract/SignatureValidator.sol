// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract SignatureValidator {
    function _isValidSignature(bytes32 hash, bytes calldata signature) internal view virtual returns (bool);
}
