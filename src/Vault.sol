// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./VaultRegistry.sol";

error NotAuthorized();
error VaultLocked();
error InvalidTransaction();

/// @title Tokenbound Vault
/// @notice A smart contract wallet owned by a single ERC721 token.
/// @author Jayden Windle
contract Vault is Initializable {
    // before any transfer
    // check nft ownership
    // extensible as fuck

    /// @dev Address of VaultRegistry
    address vaultRegistry;

    /// @dev Address of the ERC721 token contract
    address tokenCollection;

    /// @dev Token ID of the ERC721 token that controls the vault
    uint256 tokenId;

    mapping(address => uint256) unlockTimestamp;

    /**
     * @dev Called by VaultRegistry to set Vault instance parameters.
     * These parameters must remain constant, but cannot be protected by
     * the constant or immutable keywords since each deployed Vault instance
     * is a proxy.
     */
    function initialize(address _tokenCollection, uint256 _tokenId)
        public
        initializer
    {
        vaultRegistry = msg.sender;
        tokenCollection = _tokenCollection;
        tokenId = _tokenId;
    }

    /// @dev Returns the owner of the token that controls this Vault
    function owner() public view returns (address) {
        return IERC721(tokenCollection).ownerOf(tokenId);
    }

    /// @dev Returns the hash of constant storage values. Used to ensure storage values are not changed during a transaction.
    function storageHash() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(vaultRegistry, tokenCollection, tokenId)
            );
    }

    function lock(uint256 _unlockTimestamp) public payable {
        unlockTimestamp[
            IERC721(tokenCollection).ownerOf(tokenId)
        ] = _unlockTimestamp;
    }

    /**
     * @dev Executes a transaction from the Vault. Must be called by Vault owner
     * @param to      Destination address of the transaction
     * @param value   Ether value of the transaction
     * @param data    Encoded payload of the transaction
     */
    function executeCall(
        address payable to,
        uint256 value,
        bytes calldata data
    ) external payable {
        address _owner = owner();

        if (msg.sender != _owner) revert NotAuthorized();
        if (unlockTimestamp[_owner] > block.timestamp) revert VaultLocked();

        (bool success, bytes memory result) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Executes a delegated transaction from the Vault, allowing vault
     * functionality to be expanded without upgradability. Must be called by the Vault owner
     * @param to      Contract address of the delegated call
     * @param data    Encoded payload of the delegated call
     */
    function executeDelegateCall(address payable to, bytes calldata data)
        external
        payable
    {
        address _owner = owner();

        if (msg.sender != _owner) revert NotAuthorized();
        if (unlockTimestamp[_owner] > block.timestamp) revert VaultLocked();

        bytes32 cachedStorageHash = storageHash();

        (bool success, bytes memory result) = to.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        if (storageHash() != cachedStorageHash) revert InvalidTransaction();
    }

    /**
     * @dev Implements EIP-1271 signature validation
     * @param hash      Hash of the signed data
     * @param signature Signature to validate
     */
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        address _owner = owner();
        bool isValid = SignatureChecker.isValidSignatureNow(
            _owner,
            hash,
            signature
        );

        if (isValid && unlockTimestamp[_owner] < block.timestamp) {
            return IERC1271.isValidSignature.selector;
        }
    }

    // receiver functions

    /// @dev allows contract to receive Ether
    receive() external payable {}

    /// @dev ensures that fallback calls are a noop
    fallback() external payable {}

    /// @dev Allows all ERC721 tokens to be received
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @dev Allows all ERC1155 tokens to be received
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /// @dev Allows all ERC1155 token batches to be received
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
