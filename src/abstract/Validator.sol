// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract Validator {
    function _isValidSigner(address signer, bytes memory) internal view virtual returns (bool);
    function _isValidSignature(bytes32 hash, bytes calldata signature) internal view virtual returns (bool);
    function _isValidExecutor(address executor, address to, uint256 value, bytes calldata data, uint256 operation)
        internal
        view
        virtual
        returns (bool);
}
