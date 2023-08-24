// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "erc6551/interfaces/IERC6551Executable.sol";

import "../utils/Errors.sol";
import "../lib/LibExecutor.sol";
import "../lib/LibSandbox.sol";
import "./SandboxExecutor.sol";

abstract contract Executor is IERC6551Executable, ERC2771Context, SandboxExecutor {
    struct Operation {
        address to;
        uint256 value;
        bytes data;
        uint256 operation;
    }

    uint256 constant OP_CALL = 0;
    uint256 constant OP_DELEGATECALL = 1;
    uint256 constant OP_CREATE = 2;
    uint256 constant OP_CREATE2 = 3;

    constructor(address multicallForwarder) ERC2771Context(multicallForwarder) {}

    function execute(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        returns (bytes memory)
    {
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();

        _beforeExecute();

        return _execute(to, value, data, operation);
    }

    function executeBatch(Operation[] calldata operations) external payable returns (bytes[] memory) {
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();

        _beforeExecute();

        uint256 length = operations.length;
        bytes[] memory results = new bytes[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _execute(operations[i].to, operations[i].value, operations[i].data, operations[i].operation);
        }

        return results;
    }

    function _execute(address to, uint256 value, bytes calldata data, uint256 operation)
        internal
        returns (bytes memory)
    {
        if (operation == OP_CALL) return LibExecutor._call(to, value, data);
        if (operation == OP_DELEGATECALL) {
            return LibExecutor._call(LibSandbox.sandbox(address(this)), value, abi.encodePacked(to, data));
        }
        if (operation == OP_CREATE) return abi.encodePacked(LibExecutor._create(value, data));
        if (operation == OP_CREATE2) return abi.encodePacked(LibExecutor._create2(value, data));

        revert InvalidOperation();
    }

    function _beforeExecute() internal virtual {}

    function _isValidExecutor(address executor) internal view virtual returns (bool);
}
