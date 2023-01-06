// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IExecutionModule {
    function isAuthorized(address caller) external view returns (bool);

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue);
}
