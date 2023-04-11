// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MockReverter.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";

contract MockExecutor is MockReverter {
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

    function supportsInterface(bytes4 interfaceId)
        external
        pure
        returns (bool)
    {
        return interfaceId == IERC1271.isValidSignature.selector;
    }
}
