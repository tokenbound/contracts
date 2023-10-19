// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/Errors.sol";
import "./LibSandbox.sol";

library LibExecutor {
    uint8 constant OP_CALL = 0;
    uint8 constant OP_DELEGATECALL = 1;
    uint8 constant OP_CREATE = 2;
    uint8 constant OP_CREATE2 = 3;

    function _execute(address to, uint256 value, bytes calldata data, uint8 operation)
        internal
        returns (bytes memory)
    {
        if (operation == OP_CALL) return _call(to, value, data);
        if (operation == OP_DELEGATECALL) {
            address sandbox = LibSandbox.sandbox(address(this));
            if (sandbox.code.length == 0) LibSandbox.deploy(address(this));
            return _call(sandbox, value, abi.encodePacked(to, data));
        }
        if (operation == OP_CREATE) return abi.encodePacked(_create(value, data));
        if (operation == OP_CREATE2) {
            bytes32 salt = bytes32(data[:32]);
            bytes calldata bytecode = data[32:];
            return abi.encodePacked(_create2(value, salt, bytecode));
        }

        revert InvalidOperation();
    }

    function _call(address to, uint256 value, bytes memory data)
        internal
        returns (bytes memory result)
    {
        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _create(uint256 value, bytes memory data) internal returns (address created) {
        bytes memory bytecode = data;

        assembly {
            created := create(value, add(bytecode, 0x20), mload(bytecode))
        }

        if (created == address(0)) revert ContractCreationFailed();
    }

    function _create2(uint256 value, bytes32 salt, bytes calldata data)
        internal
        returns (address created)
    {
        bytes memory bytecode = data;

        assembly {
            created := create2(value, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (created == address(0)) revert ContractCreationFailed();
    }
}
