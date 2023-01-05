// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./VaultRegistry.sol";
import "./interfaces/IVault.sol";
import "./MinimalReceiver.sol";

error NotAuthorized();

/**
 * @title Default Vault Implementation
 * @dev A smart contract wallet owned by a single ERC721 token
 */
contract Vault is MinimalReceiver {
    /**
     * @dev Address of VaultRegistry
     */
    VaultRegistry public immutable registry;

    constructor(address _registry) {
        registry = VaultRegistry(_registry);
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
        if (!isAuthorized(msg.sender)) revert NotAuthorized();

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
        if (!isAuthorized(msg.sender)) revert NotAuthorized();

        (bool success, bytes memory result) = to.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
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
        bool _isAuthorized = isAuthorized(_owner);

        bool isValid = SignatureChecker.isValidSignatureNow(
            _owner,
            hash,
            signature
        );

        if (isValid && _isAuthorized) {
            return IERC1271.isValidSignature.selector;
        }
    }

    /**
     * @dev Returns the owner of the token that controls this Vault (for Ownable compatibility)
     */
    function owner() public view returns (address) {
        return registry.vaultOwner(address(this));
    }

    /**
     * @dev Returns true if caller is authorized to execute actions on this vault
     * @param caller the address to query authorization for
     * @return bool true if caller is authorized, false otherwise
     */
    function isAuthorized(address caller) public view virtual returns (bool) {
        return owner() == caller;
    }
}
