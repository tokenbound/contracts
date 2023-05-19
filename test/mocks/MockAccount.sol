// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/Account.sol";

contract MockAccount is Account {
    constructor(address _guardian, address entryPoint_, string memory _name, string memory _version)
        Account(_guardian, entryPoint_, _name, _version)
    {}

    function customFunction() external pure returns (uint256) {
        return 12345;
    }
}
