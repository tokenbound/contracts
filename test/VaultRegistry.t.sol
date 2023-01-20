// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Vault.sol";
import "../src/VaultRegistry.sol";
import "../src/lib/MinimalProxyStore.sol";

contract VaultRegistryTest is Test {
    VaultRegistry public vaultRegistry;

    function setUp() public {
        vaultRegistry = new VaultRegistry();
    }

    function testDeployVault(address tokenCollection, uint256 tokenId) public {
        assertTrue(address(vaultRegistry) != address(0));

        address predictedVaultAddress = vaultRegistry.vaultAddress(
            tokenCollection,
            tokenId
        );

        address vaultAddress = vaultRegistry.deployVault(
            tokenCollection,
            tokenId
        );

        assertTrue(vaultAddress != address(0));
        assertTrue(vaultAddress == predictedVaultAddress);
        assertEq(
            MinimalProxyStore.getContext(vaultAddress),
            abi.encode(block.chainid, tokenCollection, tokenId)
        );
    }
}
