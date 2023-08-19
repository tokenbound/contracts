// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/AccountV3.sol";

contract MockAccount is AccountV3 {
    constructor(address entryPoint_, address externalStorage) AccountV3(entryPoint_, externalStorage) {}

    function customFunction() external pure returns (uint256) {
        return 12345;
    }
}
