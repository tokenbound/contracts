// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/utils/Create2.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./Vault.sol";
import "./VaultProxy.sol";
import "./MinimalReceiver.sol";
import "./LockedVault.sol";
import "./interfaces/IVault.sol";

error VaultLocked();

/**
 * @title VaultRegistry
 * @dev Determines the address for each tokenbound Vault and performs deployment of VaultProxy instances
 */
contract VaultRegistry {
    struct VaultData {
        address tokenCollection;
        uint256 tokenId;
    }

    /**
     * @dev Address of the default vault implementation
     */
    address public defaultImplementation;

    /**
     * @dev Address of the fallback implementation (used when vault is locked)
     */
    address public fallbackImplementation;

    /**
     * @dev Mapping from vault address to owner address implementation address
     */
    mapping(address => mapping(address => address)) private _implementation;

    /**
     * @dev Mapping from vault address to VaultData
     */
    mapping(address => VaultData) public vaultData;

    /**
     * @dev Mapping from vault address unlock timestamp
     */
    mapping(address => uint256) public unlockTimestamp;

    /**
     * @dev Deploys the default Vault implementation
     */
    constructor() {
        fallbackImplementation = address(new LockedVault());
        defaultImplementation = address(new Vault(address(this)));
    }

    /**
     * @dev Deploys VaultProxy instance for an ERC721 token
     * @return The address of the deployed Vault
     */
    function deployVault(address tokenCollection, uint256 tokenId)
        external
        returns (address payable)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        address vaultProxy = address(new VaultProxy{salt: salt}());

        vaultData[vaultProxy] = VaultData(tokenCollection, tokenId);

        return payable(vaultProxy);
    }

    /**
     * @dev Sets the VaultProxy implementation address, allowing for vault owners to use a custom implementation if
     * they choose to. When the token controlling the vault is transferred, the implementation address will reset.
     */
    function setVaultImplementation(address vault, address newImplementation)
        external
    {
        address owner = vaultOwner(vault);
        if (owner != msg.sender) revert NotAuthorized();
        if (vaultLocked(vault)) revert VaultLocked();

        _implementation[vault][owner] = newImplementation;
    }

    /**
     * @dev Locks a vault, preventing transactions from being executed until a certain time
     * @param vault the vault to lock
     * @param _unlockTimestamp timestamp when the vault will become unlocked
     */
    function lockVault(address payable vault, uint256 _unlockTimestamp)
        external
    {
        address owner = vaultOwner(vault);
        if (owner != msg.sender) revert NotAuthorized();
        if (vaultLocked(vault)) revert VaultLocked();

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
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        bytes memory creationCode = type(VaultProxy).creationCode;

        address vaultProxy = Create2.computeAddress(
            salt,
            keccak256(creationCode)
        );

        return payable(vaultProxy);
    }

    /**
     * @dev Returns the implementation address for a vault
     * @param vault the address of the vault to query implementation for
     * @return the address of the vault implementation
     */
    function vaultImplementation(address vault)
        external
        view
        returns (address)
    {
        if (vaultLocked(vault)) return fallbackImplementation;

        address owner = vaultOwner(vault);

        address currentImplementation = _implementation[vault][owner];

        if (currentImplementation != address(0)) {
            return currentImplementation;
        }

        return defaultImplementation;
    }

    /**
     * @dev Returns the owner of the Vault, which is the owner of the underlying ERC721 token
     * @param vault the address of the vault to query ownership for
     * @return the address of the vault owner
     */
    function vaultOwner(address vault) public view returns (address) {
        VaultData memory data = vaultData[vault];

        if (data.tokenCollection == address(0)) {
            return address(0);
        }

        return IERC721(data.tokenCollection).ownerOf(data.tokenId);
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
