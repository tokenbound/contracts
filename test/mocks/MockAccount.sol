// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/Account.sol";

contract MockAccount is Account {
    constructor(address _guardian, address entryPoint_)
        Account(_guardian, entryPoint_)
    {}

    function customFunction() external pure returns (uint256) {
        return 12345;
    }
}
