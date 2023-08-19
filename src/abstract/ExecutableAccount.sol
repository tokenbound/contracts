// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "erc6551/interfaces/IERC6551Executable.sol";

error NotAuthorized();
error InvalidOperation();
error ContractCreationFailed();

abstract contract ExecutableAccount is IERC6551Executable {
    uint256 constant OP_CALL = 0;
    uint256 constant OP_DELEGATECALL = 1;
    uint256 constant OP_CREATE = 2;
    uint256 constant OP_CREATE2 = 3;

    function execute(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        returns (bytes memory)
    {
        if (!_isValidExecutor(msg.sender, to, value, data, operation)) revert NotAuthorized();

        _beforeExecute(to, value, data, operation);

        if (operation == OP_CALL) return _call(to, value, data);
        if (operation == OP_DELEGATECALL) return _delegatecall(to, data);
        if (operation == OP_CREATE) return _create(value, data);
        if (operation == OP_CREATE2) return _create2(value, data);

        revert InvalidOperation();
    }

    function _isValidExecutor(address executor, address to, uint256 value, bytes calldata data, uint256 operation)
        internal
        view
        virtual
        returns (bool);

    function _beforeExecute(address to, uint256 value, bytes calldata data, uint256 operation) internal virtual;

    function _call(address to, uint256 value, bytes calldata data) internal returns (bytes memory result) {
        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _delegatecall(address to, bytes calldata data) internal returns (bytes memory result) {
        bool success;
        (success, result) = to.delegatecall(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _create(uint256 value, bytes calldata data) internal returns (bytes memory result) {
        bytes memory bytecode = data;
        address createdContract;

        assembly {
            createdContract := create(value, add(bytecode, 0x20), mload(bytecode))
        }

        if (createdContract == address(0)) revert ContractCreationFailed();

        return abi.encodePacked(createdContract);
    }

    function _create2(uint256 value, bytes calldata data) internal returns (bytes memory result) {
        bytes32 salt = bytes32(data[:32]);
        bytes memory bytecode = data[32:];
        address createdContract;

        assembly {
            createdContract := create2(value, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (createdContract == address(0)) revert ContractCreationFailed();

        return abi.encodePacked(createdContract);
    }
}
