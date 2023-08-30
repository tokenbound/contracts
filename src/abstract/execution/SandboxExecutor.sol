// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Create2.sol";

import "../../interfaces/ISandboxExecutor.sol";
import "../../utils/Errors.sol";
import "../../lib/LibSandbox.sol";
import "../../lib/LibExecutor.sol";

/**
 * @title Sandbox Executor
 * @dev Allows the sandbox contract for an account to execute low-level operations
 */
abstract contract SandboxExecutor is ISandboxExecutor {
    /**
     * @dev Ensures that a given caller is the sandbox for this account
     */
    function _requireFromSandbox() internal view {
        if (msg.sender != LibSandbox.sandbox(address(this))) revert NotAuthorized();
    }

    /**
     * @dev Allows the sandbox contract to execute low-level calls from this account
     */
    function extcall(address to, uint256 value, bytes calldata data)
        external
        returns (bytes memory result)
    {
        _requireFromSandbox();
        return LibExecutor._call(to, value, data);
    }

    /**
     * @dev Allows the sandbox contract to create contracts on behalf of this account
     */
    function extcreate(uint256 value, bytes calldata bytecode) external returns (address) {
        _requireFromSandbox();

        return LibExecutor._create(value, bytecode);
    }

    /**
     * @dev Allows the sandbox contract to create deterministic contracts on behalf of this account
     */
    function extcreate2(uint256 value, bytes32 salt, bytes calldata bytecode)
        external
        returns (address)
    {
        _requireFromSandbox();
        return LibExecutor._create2(value, salt, bytecode);
    }

    /**
     * @dev Allows arbitrary storage reads on this account from external contracts
     */
    function extsload(bytes32 slot) external view returns (bytes32 value) {
        assembly {
            value := sload(slot)
        }
    }
}
