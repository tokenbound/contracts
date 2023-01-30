// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IAccount {
    function owner() external view returns (address);

    function token()
        external
        view
        returns (address tokenContract, uint256 tokenId);

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory);
}
