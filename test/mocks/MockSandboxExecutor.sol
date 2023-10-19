// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../src/interfaces/ISandboxExecutor.sol";
import "./MockReverter.sol";
import "./MockERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract MockSandboxExecutor is MockReverter {
    function customFunction() external pure returns (uint256) {
        return 12345;
    }

    function sentEther(address to, uint256 value) external returns (bytes memory) {
        return ISandboxExecutor(msg.sender).extcall(to, value, "");
    }

    function createNFT() external returns (address) {
        return ISandboxExecutor(msg.sender).extcreate(0, type(MockERC721).creationCode);
    }

    function createNFTDeterministic() external returns (address) {
        return ISandboxExecutor(msg.sender).extcreate2(
            0, keccak256("salt"), type(MockERC721).creationCode
        );
    }

    function getSlot0() external view returns (bytes32) {
        return ISandboxExecutor(msg.sender).extsload(bytes32(0));
    }
}
