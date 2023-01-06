// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";

contract MinimalReceiver {
    /**
     * @dev allows contract to receive Ether
     */
    receive() external payable virtual {}

    /**
     * @dev ensures that payable fallback calls are a noop
     */
    fallback() external payable virtual {}

    /**
     * @dev Allows all ERC721 tokens to be received
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure virtual returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev Allows all ERC1155 tokens to be received
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata /* data */
    ) external pure virtual returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /**
     * @dev Allows all ERC1155 token batches to be received
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure virtual returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
