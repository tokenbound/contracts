// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/Errors.sol";

library LibExecutor {
    function _call(address to, uint256 value, bytes memory data) internal returns (bytes memory result) {
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

    function _create2(uint256 value, bytes32 salt, bytes calldata data) internal returns (address created) {
        bytes memory bytecode = data;

        assembly {
            created := create2(value, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (created == address(0)) revert ContractCreationFailed();
    }
}
