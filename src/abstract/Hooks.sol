// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract Hooks {
    function _beforeExecute(address to, uint256 value, bytes calldata data, uint256 operation) internal virtual;
}
