// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../utils/Errors.sol";

import "./BaseExecutor.sol";

/**
 * @title Batch Executor
 * @dev Allows multiple operations to be executed from this account in a single transaction
 */
abstract contract BatchExecutor is BaseExecutor {
    struct Operation {
        address to;
        uint256 value;
        bytes data;
        uint8 operation;
    }

    /**
     * @notice Executes a batch of operations if the caller is authorized
     * @param operations Operations to execute
     */
    function executeBatch(Operation[] calldata operations)
        external
        payable
        returns (bytes[] memory)
    {
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();

        _beforeExecute();

        uint256 length = operations.length;
        bytes[] memory results = new bytes[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = LibExecutor._execute(
                operations[i].to, operations[i].value, operations[i].data, operations[i].operation
            );
        }

        return results;
    }
}
