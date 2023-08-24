// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "erc6551/interfaces/IERC6551Executable.sol";
import "../utils/Errors.sol";
import "../lib/LibExecutor.sol";
import "../lib/LibSandbox.sol";
import "./Hooks.sol";
import "./Validator.sol";

abstract contract Executor is IERC6551Executable, Validator, Hooks {
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

        if (operation == OP_CALL) return LibExecutor._call(to, value, data);
        if (operation == OP_DELEGATECALL) {
            return LibExecutor._call(LibSandbox.sandbox(address(this)), value, abi.encodePacked(to, data));
        }
        if (operation == OP_CREATE) return abi.encodePacked(LibExecutor._create(value, data));
        if (operation == OP_CREATE2) return abi.encodePacked(LibExecutor._create2(value, data));

        revert InvalidOperation();
    }
}
