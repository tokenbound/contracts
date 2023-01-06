// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVault {
    function executeCall(
        address payable to,
        uint256 value,
        bytes calldata data,
        bool useExecutionModule
    ) external payable;

    function executeDelegateCall(
        address payable to,
        bytes calldata data,
        bool useExecutionModule
    ) external payable;

    receive() external payable;

    fallback() external payable;

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4);

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata /* data */
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external returns (bytes4);

    function owner() external view returns (address);

    function isAuthorized(address caller) external view returns (bool);

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue);
}
