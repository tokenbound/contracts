// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {BaseAccount as BaseERC4337Account} from "account-abstraction/core/BaseAccount.sol";

abstract contract ERC4337Account is BaseERC4337Account {
    using ECDSA for bytes32;

    IEntryPoint immutable _entryPoint;

    constructor(address entryPoint_) {
        _entryPoint = IEntryPoint(entryPoint_);
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (_isValidSignature(_getUserOpSignatureHash(userOp, userOpHash), userOp.signature)) {
            return 0;
        }

        return 1;
    }

    function _getUserOpSignatureHash(UserOperation calldata, bytes32 userOpHash)
        internal
        view
        virtual
        returns (bytes32)
    {
        return userOpHash.toEthSignedMessageHash();
    }

    function _isValidSignature(bytes32 hash, bytes calldata signature) internal view virtual returns (bool);
}
