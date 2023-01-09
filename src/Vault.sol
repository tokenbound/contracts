// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts/utils/Address.sol";

import "./interfaces/IVault.sol";
import "./lib/MinimalProxyStore.sol";

/**
 * @title A smart contract wallet owned by a single ERC721 token
 * @author Jayden Windle (jaydenwindle)
 */
contract Vault is IVault {
    error NotAuthorized();
    error VaultLocked();

    // unlock timestamp
    uint256 unlockTimestamp;

    // owner -> executor
    mapping(address => address) executor;

    function isLocked() public view returns (bool) {
        return unlockTimestamp > block.timestamp;
    }

    function isOwnerOrExecutor(address caller) internal view returns (bool) {
        address _owner = owner();
        if (caller == _owner) return true;

        address _executor = executor[_owner];
        if (caller == _executor) return true;

        return false;
    }

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
        bytes calldata data
    ) external payable returns (bytes memory result) {
        if (isLocked()) revert VaultLocked();
        if (!isOwnerOrExecutor(msg.sender)) revert NotAuthorized();

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Sets the executior address for Vault, allowing for vault owners to use a custom implementation if
     * they choose to. When the token controlling the vault is transferred, the implementation address will reset
     *
     * @param _executionModule the address of the execution module
     */
    function setExecutor(address _executionModule) external {
        if (isLocked()) revert VaultLocked();

        address _owner = owner();
        if (_owner != msg.sender) revert NotAuthorized();

        executor[_owner] = _executionModule;
    }

    /**
     * @dev Locks vault, preventing transactions from being executed until a certain time
     *
     * @param _unlockTimestamp timestamp when the vault will become unlocked
     */
    function lock(uint256 _unlockTimestamp) external {
        if (isLocked()) revert VaultLocked();

        address _owner = owner();
        if (_owner != msg.sender) revert NotAuthorized();

        unlockTimestamp = _unlockTimestamp;
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
        // If vault is locked, disable signing
        if (isLocked()) return "";

        // If vault has an executor, check if executor signature is valid
        address _owner = owner();
        address _executor = executor[_owner];

        if (
            _executor != address(0) &&
            SignatureChecker.isValidSignatureNow(_executor, hash, signature)
        ) {
            return IERC1271.isValidSignature.selector;
        }

        // Default - check if signature is valid for vault owner
        if (SignatureChecker.isValidSignatureNow(_owner, hash, signature)) {
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
        bytes memory context = MinimalProxyStore.getContext(address(this));

        if (context.length == 0) return address(0);

        (address tokenCollection, uint256 tokenId) = abi.decode(
            context,
            (address, uint256)
        );

        return IERC721(tokenCollection).ownerOf(tokenId);
    }

    /**
     * @dev Returns true if caller is authorized to execute actions on this vault
     *
     * @param caller the address to query authorization for
     * @return bool true if caller is authorized, false otherwise
     */
    function isAuthorized(address caller) public view virtual returns (bool) {
        return isOwnerOrExecutor(caller);
    }

    /**
     * @dev If vault is unlocked and an execution module is defined, delegate execution to the execution module
     */
    fallback(bytes calldata input)
        external
        payable
        returns (bytes memory output)
    {
        if (isLocked()) revert VaultLocked();
        address _owner = owner();
        address _executor = executor[_owner];

        if (_executor == address(0)) return "";

        return Address.functionCall(_executor, input);
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
