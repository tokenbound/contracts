// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "openzeppelin-contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";

import "./MinimalReceiver.sol";
import "./interfaces/IVault.sol";
import "./lib/MinimalProxyStore.sol";

/**
 * @title A smart contract wallet owned by a single ERC721 token
 * @author Jayden Windle (jaydenwindle)
 */
contract Vault is IVault, MinimalReceiver {
    error NotAuthorized();
    error VaultLocked();
    error ExceedsMaxLockTime();

    /**
     * @dev Timestamp at which Vault will unlock
     */
    uint256 public unlockTimestamp;

    /**
     * @dev Mapping from owner address to executor address
     */
    mapping(address => address) public executor;

    modifier onlyUnlocked() {
        if (unlockTimestamp > block.timestamp) revert VaultLocked();
        _;
    }

    /**
     * @dev Emitted whenever the lock status of a vault is updated
     */
    event LockUpdated(uint256 timestamp);

    /**
     * @dev Emitted whenever the executor for a vault is updated
     */
    event ExecutorUpdated(address owner, address executor);

    /**
     * @dev If vault is unlocked and an executor is set, pass call to executor
     */
    fallback(bytes calldata data)
        external
        payable
        onlyUnlocked
        returns (bytes memory result)
    {
        address _owner = owner();
        address _executor = executor[_owner];

        // accept funds if executor is undefined or cannot be called
        if (_executor == address(0)) return "";
        if (_executor.code.length == 0) return "";

        bool success;
        (success, result) = _executor.call(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Executes a transaction from the Vault. Must be called by an authorized sender.
     *
     * @param to      Destination address of the transaction
     * @param value   Ether value of the transaction
     * @param data    Encoded payload of the transaction
     */
    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable onlyUnlocked returns (bytes memory result) {
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
     * @dev Sets executior address for Vault, allowing owner to use a custom implementation if they choose to.
     * When the token controlling the vault is transferred, the implementation address will reset
     *
     * @param _executionModule the address of the execution module
     */
    function setExecutor(address _executionModule) external onlyUnlocked {
        address _owner = owner();
        if (_owner != msg.sender) revert NotAuthorized();

        executor[_owner] = _executionModule;

        emit ExecutorUpdated(_owner, _executionModule);
    }

    /**
     * @dev Locks Vault, preventing transactions from being executed until a certain time
     *
     * @param _unlockTimestamp timestamp when the vault will become unlocked
     */
    function lock(uint256 _unlockTimestamp) external onlyUnlocked {
        if (_unlockTimestamp > block.timestamp + 365 days)
            revert ExceedsMaxLockTime();

        address _owner = owner();
        if (_owner != msg.sender) revert NotAuthorized();

        unlockTimestamp = _unlockTimestamp;

        emit LockUpdated(_unlockTimestamp);
    }

    /**
     * @dev Returns Vault lock status
     *
     * @return true if Vault is locked, false otherwise
     */
    function isLocked() external view returns (bool) {
        return unlockTimestamp > block.timestamp;
    }

    /**
     * @dev Returns true if caller is authorized to execute actions on this vault
     *
     * @param caller the address to query authorization for
     * @return true if caller is authorized, false otherwise
     */
    function isAuthorized(address caller) external view returns (bool) {
        return isOwnerOrExecutor(caller);
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
        if (unlockTimestamp > block.timestamp) return "";

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver)
        returns (bool)
    {
        // default interface support
        if (
            interfaceId == type(IVault).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId
        ) {
            return true;
        }

        // if interface is not supported by default, check executor
        return IERC165(executor[owner()]).supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the owner of the token that controls this Vault (public for Ownable compatibility)
     *
     * @return the address of the Vault owner
     */
    function owner() public view returns (address) {
        bytes memory context = MinimalProxyStore.getContext(address(this));

        if (context.length == 0) return address(0);

        (uint256 chainId, address tokenCollection, uint256 tokenId) = abi
            .decode(context, (uint256, address, uint256));

        if (chainId != block.chainid) {
            return address(0);
        }

        return IERC721(tokenCollection).ownerOf(tokenId);
    }

    /**
     * @dev Returns true if caller is owner or ececutor
     *
     * @param caller the address to query for
     * @return true if caller is owner or executor, false otherwise
     */
    function isOwnerOrExecutor(address caller) internal view returns (bool) {
        address _owner = owner();
        if (caller == _owner) return true;

        address _executor = executor[_owner];
        if (caller == _executor) return true;

        return false;
    }
}
