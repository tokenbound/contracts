// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {BaseAccount as BaseERC4337Account, UserOperation} from "account-abstraction/core/BaseAccount.sol";

import "./SignatureValidator.sol";

abstract contract ERC4337Account is BaseERC4337Account, SignatureValidator {
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
        override
        returns (uint256)
    {
        if (_isValidSignature(userOpHash.toEthSignedMessageHash(), userOp.signature)) {
            return 0;
        }

        return 1;
    }
}
