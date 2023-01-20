// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC1271.sol";

interface IVault is IERC1271 {
    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory);

    function executor(address owner) external view returns (address);

    function setExecutor(address _executionModule) external;

    function isLocked() external view returns (bool);

    function lock(uint256 _unlockTimestamp) external;

    function isAuthorized(address caller) external view returns (bool);

    function owner() external view returns (address);
}
