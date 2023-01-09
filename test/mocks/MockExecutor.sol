// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC1271.sol";

contract MockExecutor {
    function customFunction() external pure returns (uint256) {
        return 12345;
    }
}
