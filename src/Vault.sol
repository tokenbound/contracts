// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import "./VaultRegistry.sol";

error AlreadyInitialized();

contract Vault is Initializable {
    // before any transfer
    // check nft ownership
    // extensible as fuck

    VaultRegistry vaultRegistry;

    function initialize(address _vaultRegistry) public initializer {
        vaultRegistry = VaultRegistry(_vaultRegistry);
    }

    modifier onlyOwner(address tokenCollection, uint256 tokenId) {
        require(
            msg.sender == IERC721(tokenCollection).ownerOf(tokenId),
            "Not owner"
        );
        _;
    }

    modifier onlyVault(address tokenCollection, uint256 tokenId) {
        require(
            address(this) ==
                address(vaultRegistry.getVault(tokenCollection, tokenId)),
            "Not vault"
        );
        _;
    }

    function execTransaction(
        address payable to,
        uint256 value,
        bytes calldata data,
        address tokenCollection,
        uint256 tokenId
    )
        public
        payable
        onlyVault(tokenCollection, tokenId)
        onlyOwner(tokenCollection, tokenId)
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = to.call{value: value}(data);
    }

    function isValidSignature(
        bytes32 _hash,
        bytes memory _signature,
        address tokenCollection,
        uint256 tokenId
    )
        public
        view
        onlyVault(tokenCollection, tokenId)
        returns (bytes4 magicValue)
    {
        (address signer, ECDSA.RecoverError error) = ECDSA.tryRecover(
            _hash,
            _signature
        );

        if (
            error == ECDSA.RecoverError.NoError &&
            signer == IERC721(tokenCollection).ownerOf(tokenId)
        ) {
            return this.isValidSignature.selector;
        }
    }

    // receiver functions

    receive() external payable {}

    fallback() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
