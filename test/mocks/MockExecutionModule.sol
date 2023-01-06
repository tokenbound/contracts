// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "../../src/interfaces/IExecutionModule.sol";

contract MockExecutionModule is IExecutionModule {
    function isAuthorized(address) external pure returns (bool) {
        return true;
    }

    function isValidSignature(bytes32, bytes memory)
        external
        pure
        returns (bytes4 magicValue)
    {
        return IERC1271.isValidSignature.selector;
    }

    function customFunction() external pure returns (uint256) {
        return 12345;
    }
}
