// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract MockSigner is IERC1271 {
    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4 magicValue) {
        return IERC1271.isValidSignature.selector;
    }
}
