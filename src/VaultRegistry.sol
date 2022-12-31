// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/utils/Create2.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./Vault.sol";
import "./VaultProxy.sol";
import "./interfaces/IVault.sol";

/// @title VaultRegistry
/// @notice Determines the address for each tokenbound Vault and performs deployment of Vault instances
/// @author Jayden Windle
contract VaultRegistry {
    address public defaultImplementation;

    struct VaultData {
        address tokenCollection;
        uint256 tokenId;
    }

    /// @dev mapping from vault address to VaultData
    mapping(address => VaultData) public vaultData;

    /// @dev mapping from vault address to owner address implementation address
    mapping(address => mapping(address => address)) private _implementation;

    /// @dev deploys the canonical vault implementation
    constructor() {
        defaultImplementation = address(new Vault(address(this)));
    }

    /**
     * @dev Deploys the Vault instance for an ERC721 token.
     * @return The address of the deployed Vault
     */
    function deployVault(address tokenCollection, uint256 tokenId)
        public
        returns (address payable)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        address vaultProxy = address(new VaultProxy{salt: salt}());

        vaultData[vaultProxy] = VaultData(tokenCollection, tokenId);

        return payable(vaultProxy);
    }

    /**
     * @dev Gets the address of the Vault for an ERC721 token. If Vault is not deployed,
     * the return value is the address that the Vault will eventually be deployed to
     * @return The Vault address
     */
    function vaultAddress(address tokenCollection, uint256 tokenId)
        public
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

    /// @dev Returns the owner of the Vault, which is the owner of the underlying ERC721 token
    function vaultOwner(address vault) public view returns (address) {
        VaultData memory data = vaultData[vault];

        if (data.tokenCollection == address(0)) {
            return address(0);
        }

        return IERC721(data.tokenCollection).ownerOf(data.tokenId);
    }

    function vaultImplementation(address vault) public view returns (address) {
        address owner = vaultOwner(vault);
        address currentImplementation = _implementation[vault][owner];

        if (currentImplementation != address(0)) {
            return currentImplementation;
        }

        return defaultImplementation;
    }

    function setVaultImplementation(
        address payable vault,
        address newImplementation
    ) external {
        address owner = vaultOwner(vault);
        Vault _vault = Vault(vault);
        bool isAuthorized = _vault.isAuthorized(msg.sender);

        if (owner != msg.sender || !isAuthorized) revert NotAuthorized();

        _implementation[vault][owner] = newImplementation;
    }
}
