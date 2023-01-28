// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable2Step.sol";

import "./Account.sol";
import "./CrossChainExecutorList.sol";
import "./lib/MinimalProxyStore.sol";

/**
 * @title A registry for tokenbound Accounts
 * @dev Determines the address for each tokenbound Account and performs deployment of account instances
 * @author Jayden Windle (jaydenwindle)
 */
contract AccountRegistry is Ownable2Step {
    error NotAuthorized();
    error AccountLocked();

    /**
     * @dev Address of the default account implementation
     */
    address public immutable defaultImplementation;

    /**
     * @dev Emitted whenever a account is created
     */
    event AccountCreated(
        address account,
        uint256 chainId,
        address tokenCollection,
        uint256 tokenId
    );

    /**
     * @dev Deploys the default Account implementation
     */
    constructor() {
        address crossChainExecutorList = address(new CrossChainExecutorList());
        defaultImplementation = address(
            new Account(address(this), crossChainExecutorList)
        );
    }

    /**
     * @dev Creates the Account instance for an ERC721 token. Will revert if Account has already been deployed
     *
     * @param chainId the chainid of the network the ERC721 token exists on
     * @param tokenCollection the contract address of the ERC721 token which will control the deployed Account
     * @param tokenId the token ID of the ERC721 token which will control the deployed Account
     * @return The address of the deployed Account
     */
    function createAccount(
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
        address accountProxy = MinimalProxyStore.cloneDeterministic(
            defaultImplementation,
            encodedTokenData,
            salt
        );

        emit AccountCreated(accountProxy, chainId, tokenCollection, tokenId);

        return accountProxy;
    }

    /**
     * @dev Deploys the Account instance for an ERC721 token. Will revert if Account has already been deployed
     *
     * @param tokenCollection the contract address of the ERC721 token which will control the deployed Account
     * @param tokenId the token ID of the ERC721 token which will control the deployed Account
     * @return The address of the deployed Account
     */
    function createAccount(address tokenCollection, uint256 tokenId)
        external
        returns (address)
    {
        return this.createAccount(block.chainid, tokenCollection, tokenId);
    }

    /**
     * @dev Gets the address of the AccountProxy for an ERC721 token. If AccountProxy is
     * not yet deployed, returns the address it will be deployed to
     *
     * @param chainId the chainid of the network the ERC721 token exists on
     * @param tokenCollection the address of the ERC721 token contract
     * @param tokenId the tokenId of the ERC721 token that controls the account
     * @return The AccountProxy address
     */
    function account(
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

        address accountProxy = MinimalProxyStore.predictDeterministicAddress(
            defaultImplementation,
            encodedTokenData,
            salt
        );

        return accountProxy;
    }

    /**
     * @dev Gets the address of the AccountProxy for an ERC721 token. If AccountProxy is
     * not yet deployed, returns the address it will be deployed to
     *
     * @param tokenCollection the address of the ERC721 token contract
     * @param tokenId the tokenId of the ERC721 token that controls the account
     * @return The AccountProxy address
     */
    function account(address tokenCollection, uint256 tokenId)
        external
        view
        returns (address)
    {
        return this.account(block.chainid, tokenCollection, tokenId);
    }
}
