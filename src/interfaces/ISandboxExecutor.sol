// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ISandboxExecutor {
    function extcall(address to, uint256 value, bytes calldata data)
        external
        returns (bytes memory result);

    function extcreate(uint256 value, bytes calldata data) external returns (address);

    function extcreate2(uint256 value, bytes32 salt, bytes calldata bytecode)
        external
        returns (address);

    function extsload(bytes32 slot) external view returns (bytes32 value);
}
