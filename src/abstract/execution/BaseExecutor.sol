// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Context.sol";

import "./SandboxExecutor.sol";

/**
 * @title Base Executor
 * @dev Base configuration for all executors
 */
abstract contract BaseExecutor is Context, SandboxExecutor {
    function _beforeExecute() internal virtual {}

    function _isValidExecutor(address executor) internal view virtual returns (bool);
}
