// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable2Step.sol";

import "./Account.sol";
import "./lib/MinimalProxyStore.sol";

/**
 * @title A registry for tokenbound Vaults
 * @dev Determines the address for each tokenbound Vault and performs deployment of vault instances
 * @author Jayden Windle (jaydenwindle)
 */
contract VaultRegistry is Ownable2Step {
    error NotAuthorized();
    error VaultLocked();

    /**
     * @dev Address of the default vault implementation
     */
    address public immutable defaultImplementation;

    mapping(uint256 => mapping(address => bool)) public isCrossChainExecutor;

    /**
     * @dev Emitted whenever a vault is created
     */
    event VaultCreated(address vault, address tokenCollection, uint256 tokenId);

    /**
     * @dev Deploys the default Vault implementation
     */
    constructor() {
        defaultImplementation = address(new Account());
    }

    /**
     * @dev Deploys the Vault instance for an ERC721 token. Will revert if Vault has already been deployed
     *
     * @param chainId the chainid of the network the ERC721 token exists on
     * @param tokenCollection the contract address of the ERC721 token which will control the deployed Vault
     * @param tokenId the token ID of the ERC721 token which will control the deployed Vault
     * @return The address of the deployed Vault
     */
    function deployAccount(
        uint256 chainId,
        address tokenCollection,
        uint256 tokenId
    ) external returns (address) {
        bytes memory encodedTokenData = abi.encode(
            chainId,
            tokenCollection,
            tokenId
        );
        bytes32 salt = keccak256(encodedTokenData);
        address vaultProxy = MinimalProxyStore.cloneDeterministic(
            defaultImplementation,
            encodedTokenData,
            salt
        );

        emit VaultCreated(vaultProxy, tokenCollection, tokenId);

        return vaultProxy;
    }

    /**
     * @dev Deploys the Vault instance for an ERC721 token. Will revert if Vault has already been deployed
     *
     * @param tokenCollection the contract address of the ERC721 token which will control the deployed Vault
     * @param tokenId the token ID of the ERC721 token which will control the deployed Vault
     * @return The address of the deployed Vault
     */
    function deployAccount(address tokenCollection, uint256 tokenId)
        external
        returns (address)
    {
        return this.deployAccount(block.chainid, tokenCollection, tokenId);
    }

    /**
     * @dev Enables or disables a trusted cross-chain executor.
     *
     * @param chainId the chainid of the network the executor exists on
     * @param executor the address of the executor
     * @param enabled true if executor should be enabled, false otherwise
     */
    function setCrossChainExecutor(
        uint256 chainId,
        address executor,
        bool enabled
    ) external onlyOwner {
        isCrossChainExecutor[chainId][executor] = enabled;
    }

    /**
     * @dev Gets the address of the VaultProxy for an ERC721 token. If VaultProxy is
     * not yet deployed, returns the address it will be deployed to
     *
     * @param chainId the chainid of the network the ERC721 token exists on
     * @param tokenCollection the address of the ERC721 token contract
     * @param tokenId the tokenId of the ERC721 token that controls the vault
     * @return The VaultProxy address
     */
    function vaultAddress(
        uint256 chainId,
        address tokenCollection,
        uint256 tokenId
    ) external view returns (address) {
        bytes memory encodedTokenData = abi.encode(
            chainId,
            tokenCollection,
            tokenId
        );
        bytes32 salt = keccak256(encodedTokenData);

        address vaultProxy = MinimalProxyStore.predictDeterministicAddress(
            defaultImplementation,
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
        return this.vaultAddress(block.chainid, tokenCollection, tokenId);
    }
}
