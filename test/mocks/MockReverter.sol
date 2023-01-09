// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockReverter {
    error MockError();

    function fail() external pure returns (uint256) {
        revert MockError();
    }
}

