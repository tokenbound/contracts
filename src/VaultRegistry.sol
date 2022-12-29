// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/utils/Create2.sol";

import "./Vault.sol";

/// @title VaultRegistry
/// @notice Determines the address for each tokenbound Vault and performs deployment of Vault instances
/// @author Jayden Windle
contract VaultRegistry {
    address public vaultImplementation;

    constructor(address _vaultImplementation) {
        vaultImplementation = _vaultImplementation;
    }

    /**
     * @dev Gets the address of the Vault for an ERC721 token. If Vault is not deployed,
     * the return value is the address that the Vault will eventually be deployed to
     * @return The Vault address
     */
    function getVault(address tokenCollection, uint256 tokenId)
        public
        view
        returns (address payable)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        address vaultAddress = Clones.predictDeterministicAddress(
            vaultImplementation,
            salt
        );
        return payable(vaultAddress);
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
        address vaultAddress = Clones.cloneDeterministic(
            vaultImplementation,
            salt
        );

        Vault vault = Vault(payable(vaultAddress));
        vault.initialize(tokenCollection, tokenId);

        return payable(vaultAddress);
    }
}
