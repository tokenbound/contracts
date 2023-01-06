// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./VaultRegistry.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IExecutionModule.sol";
import "./lib/MinimalProxyStore.sol";
import "./lib/Delegate.sol";

/**
 * @title A smart contract wallet owned by a single ERC721 token
 * @author Jayden Windle (jaydenwindle)
 */
contract Vault is IVault {
    error NotAuthorized();

    /**
     * @dev Address of VaultRegistry
     */
    VaultRegistry public immutable registry = VaultRegistry(msg.sender);

    /**
     * @dev Executes a transaction from the Vault. Must be called by an authorized sender.
     *
     * @param to      Destination address of the transaction
     * @param value   Ether value of the transaction
     * @param data    Encoded payload of the transaction
     */
    function executeCall(
        address payable to,
        uint256 value,
        bytes calldata data,
        bool useExecutionModule
    ) external payable {
        if (!_isAuthorized(msg.sender, useExecutionModule))
            revert NotAuthorized();

        (bool success, bytes memory result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Executes a delegated transaction from the Vault, allowing vault
     * functionality to be expanded without setting an execution module. Must be called by an authorized sender.
     *
     * @param to      Contract address of the delegated call
     * @param data    Encoded payload of the delegated call
     */
    function executeDelegateCall(
        address payable to,
        bytes calldata data,
        bool useExecutionModule
    ) external payable {
        if (!_isAuthorized(msg.sender, useExecutionModule))
            revert NotAuthorized();

        (bool success, bytes memory result) = to.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Implements EIP-1271 signature validation
     *
     * @param hash      Hash of the signed data
     * @param signature Signature to validate
     */
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        // If vault is locked, return invalid for all signatures
        bool isLocked = registry.vaultLocked(address(this));
        if (isLocked) {
            return "";
        }

        // If vault has an executionModule, return its verification result
        address _owner = owner();
        address executionModule = registry.vaultExecutionModule(
            address(this),
            _owner
        );
        if (executionModule != address(0)) {
            return
                IExecutionModule(executionModule).isValidSignature(
                    hash,
                    signature
                );
        }

        // Default - check if signature is valid for vault owner
        bool isValid = SignatureChecker.isValidSignatureNow(
            _owner,
            hash,
            signature
        );
        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    /**
     * @dev Returns the owner of the token that controls this Vault (for Ownable compatibility)
     *
     * @return the address of the Vault owner
     */
    function owner() public view returns (address) {
        bytes memory context = MinimalProxyStore.getContext(address(this), 64);

        if (context.length == 0) return address(0);

        (address tokenCollection, uint256 tokenId) = abi.decode(
            context,
            (address, uint256)
        );

        return IERC721(tokenCollection).ownerOf(tokenId);
    }

    /**
     * @dev Returns true if caller is authorized to execute actions on this vault. Only uses execution module for auth
     * if useExecutionModule is set to true.
     *
     * @param caller the address to query authorization for
     * @return bool true if caller is authorized, false otherwise
     */
    function _isAuthorized(address caller, bool useExecutionModule)
        internal
        view
        returns (bool)
    {
        // If vault is locked, return false for all auth queries
        bool isLocked = registry.vaultLocked(address(this));
        if (isLocked) {
            return false;
        }

        address _owner = owner();

        // If useExecutionModule is set, lookup executionModule
        address executionModule;
        if (useExecutionModule) {
            executionModule = registry.vaultExecutionModule(
                address(this),
                _owner
            );
        }

        // if useExecutionModule is false or executionModule is not set, return default auth
        if (executionModule == address(0)) return caller == _owner;

        // If executionModule is set, query it for auth status
        return IExecutionModule(executionModule).isAuthorized(caller);
    }

    /**
     * @dev Returns true if caller is authorized to execute actions on this vault
     *
     * @param caller the address to query authorization for
     * @return bool true if caller is authorized, false otherwise
     */
    function isAuthorized(address caller) public view virtual returns (bool) {
        return _isAuthorized(caller, true);
    }

    /**
     * @dev If vault is unlocked and an execution module is defined, delegate execution to the execution module
     */
    fallback() external payable virtual {
        address _owner = owner();
        address executionModule = registry.vaultExecutionModule(
            address(this),
            _owner
        );
        bool isLocked = registry.vaultLocked(address(this));

        if (!isLocked) Delegate.delegate(executionModule);
    }

    /**
     * @dev Allows all Ether transfers
     */
    receive() external payable virtual {}

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
