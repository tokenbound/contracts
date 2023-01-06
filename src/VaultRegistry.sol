// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/utils/Create2.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./Vault.sol";
import "./MinimalReceiver.sol";
import "./interfaces/IVault.sol";

import "./lib/MinimalProxyStore.sol";

/**
 * @title VaultRegistry
 * @dev Determines the address for each tokenbound Vault and performs deployment of VaultProxy instances
 */
contract VaultRegistry {
    error NotAuthorized();
    error VaultLocked();

    /**
     * @dev Address of the default vault implementation
     */
    address public vaultImplementation;

    /**
     * @dev Mapping from vault address to owner address to execution module address
     */
    mapping(address => mapping(address => address)) private executionModule;

    /**
     * @dev Mapping from vault address unlock timestamp
     */
    mapping(address => uint256) public unlockTimestamp;

    /**
     * @dev Deploys the default Vault implementation
     */
    constructor() {
        vaultImplementation = address(new Vault());
    }

    /**
     * @dev Deploys VaultProxy instance for an ERC721 token
     * @return The address of the deployed Vault
     */
    function deployVault(address tokenCollection, uint256 tokenId)
        external
        returns (address payable)
    {
        bytes memory encodedTokenData = abi.encode(tokenCollection, tokenId);
        bytes32 salt = keccak256(encodedTokenData);
        address vaultProxy = MinimalProxyStore.cloneDeterministic(
            vaultImplementation,
            encodedTokenData,
            salt
        );

        return payable(vaultProxy);
    }

    /**
     * @dev Sets the VaultProxy implementation address, allowing for vault owners to use a custom implementation if
     * they choose to. When the token controlling the vault is transferred, the implementation address will reset.
     */
    function setExecutionModule(address vault, address _executionModule)
        external
    {
        if (vaultLocked(vault)) revert VaultLocked();

        if (vault.code.length == 0) revert NotAuthorized();

        address owner = vaultOwner(vault);
        if (owner != msg.sender) revert NotAuthorized();

        executionModule[vault][owner] = _executionModule;
    }

    /**
     * @dev Locks a vault, preventing transactions from being executed until a certain time
     * @param vault the vault to lock
     * @param _unlockTimestamp timestamp when the vault will become unlocked
     */
    function lockVault(address payable vault, uint256 _unlockTimestamp)
        external
    {
        if (vaultLocked(vault)) revert VaultLocked();

        if (vault.code.length == 0) revert NotAuthorized();

        address owner = vaultOwner(vault);
        if (owner != msg.sender) revert NotAuthorized();

        unlockTimestamp[vault] = _unlockTimestamp;
    }

    /**
     * @dev Gets the address of the VaultProxy for an ERC721 token. If VaultProxy is
     * not yet deployed, returns the address it will be deployed to
     * @param tokenCollection the address of the ERC721 token contract
     * @param tokenId the tokenId of the ERC721 token that controls the vault
     * @return The VaultProxy address
     */
    function vaultAddress(address tokenCollection, uint256 tokenId)
        external
        view
        returns (address payable)
    {
        bytes memory encodedTokenData = abi.encode(tokenCollection, tokenId);
        bytes32 salt = keccak256(encodedTokenData);

        address vaultProxy = MinimalProxyStore.predictDeterministicAddress(
            vaultImplementation,
            encodedTokenData,
            salt
        );

        return payable(vaultProxy);
    }

    /**
     * @dev Returns the implementation address for a vault
     * @param vault the address of the vault to query implementation for
     * @return the address of the vault implementation
     */
    function vaultExecutionModule(address vault, address owner)
        external
        view
        returns (address)
    {
        return executionModule[vault][owner];
    }

    /**
     * @dev Returns the owner of the Vault, which is the owner of the underlying ERC721 token
     * @param vault the address of the vault to query ownership for
     * @return the address of the vault owner
     */
    function vaultOwner(address vault) public view returns (address) {
        bytes memory context = MinimalProxyStore.getContext(vault, 64);

        if (context.length == 0) return address(0);

        (address tokenCollection, uint256 tokenId) = abi.decode(
            context,
            (address, uint256)
        );

        return IERC721(tokenCollection).ownerOf(tokenId);
    }

    /**
     * @dev Returns the lock status for a vault
     * @param vault the address of the vault to query lock status for
     * @return true if vault is locked, false otherwise
     */
    function vaultLocked(address vault) public view returns (bool) {
        return unlockTimestamp[vault] > block.timestamp;
    }
}
