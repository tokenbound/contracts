// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./MockReverter.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract MockExecutor is MockReverter {
    function customFunction() external pure returns (uint256) {
        return 12345;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x12345678;
    }

    function onERC721Received(address, address, uint256, bytes memory)
        public
        pure
        returns (bytes4)
    {
        return bytes4("");
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory)
        public
        pure
        returns (bytes4)
    {
        return bytes4("");
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return bytes4("");
    }
}
