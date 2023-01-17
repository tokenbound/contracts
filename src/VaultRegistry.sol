// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/utils/Create2.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./Vault.sol";
import "./lib/MinimalProxyStore.sol";

/**
 * @title A registry for tokenbound Vaults
 * @dev Determines the address for each tokenbound Vault and performs deployment of vault instances
 * @author Jayden Windle (jaydenwindle)
 */
contract VaultRegistry {
    error NotAuthorized();
    error VaultLocked();

    /**
     * @dev Address of the default vault implementation
     */
    address public vaultImplementation;

    /**
     * @dev Deploys the default Vault implementation
     */
    constructor() {
        vaultImplementation = address(new Vault());
    }

    /**
     * @dev Deploys the Vault instance for an ERC721 token. Will revert if Vault has already been deployed
     *
     * @param tokenCollection the contract address of the ERC721 token which will control the deployed Vault
     * @param tokenId the token ID of the ERC721 token which will control the deployed Vault
     * @return The address of the deployed Vault
     */
    function deployVault(address tokenCollection, uint256 tokenId)
        external
        returns (address)
    {
        bytes memory encodedTokenData = abi.encode(tokenCollection, tokenId);
        bytes32 salt = keccak256(encodedTokenData);
        address vaultProxy = MinimalProxyStore.cloneDeterministic(
            vaultImplementation,
            encodedTokenData,
            salt
        );

        return vaultProxy;
    }

    /**
     * @dev Gets the address of the VaultProxy for an ERC721 token. If VaultProxy is
     * not yet deployed, returns the address it will be deployed to
     *
     * @param tokenCollection the address of the ERC721 token contract
     * @param tokenId the tokenId of the ERC721 token that controls the vault
     * @return The VaultProxy address
     */
    function vaultAddress(address tokenCollection, uint256 tokenId)
        external
        view
        returns (address)
    {
        bytes memory encodedTokenData = abi.encode(tokenCollection, tokenId);
        bytes32 salt = keccak256(encodedTokenData);

        address vaultProxy = MinimalProxyStore.predictDeterministicAddress(
            vaultImplementation,
            encodedTokenData,
            salt
        );

        return vaultProxy;
    }
}
