// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Create2.sol";

import "../interfaces/ISandboxExecutor.sol";
import "../utils/Errors.sol";
import "../lib/LibSandbox.sol";
import "../lib/LibExecutor.sol";

abstract contract SandboxExecutor is ISandboxExecutor {
    function _requireFromSandbox() internal view {
        if (msg.sender != LibSandbox.sandbox(address(this))) revert NotAuthorized();
    }

    function extcall(address to, uint256 value, bytes calldata data) external returns (bytes memory result) {
        _requireFromSandbox();
        return LibExecutor._call(to, value, data);
    }

    function extcreate(uint256 value, bytes calldata bytecode) external returns (address) {
        _requireFromSandbox();

        return LibExecutor._create(value, bytecode);
    }

    function extcreate2(uint256 value, bytes32 salt, bytes calldata bytecode) external returns (address) {
        _requireFromSandbox();
        return LibExecutor._create2(value, salt, bytecode);
    }

    function extsload(bytes32 slot) external view returns (bytes32 value) {
        assembly {
            value := sload(slot)
        }
    }
}
