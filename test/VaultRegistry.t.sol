// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Vault.sol";
import "../src/VaultRegistry.sol";

contract VaultRegistryTest is Test {
    VaultRegistry public vaultRegistry;

    function setUp() public {
        vaultRegistry = new VaultRegistry();
    }

    function testDeployVault(uint256 tokenId) public {
        assertTrue(address(vaultRegistry) != address(0));

        address predictedVaultAddress = vaultRegistry.vaultAddress(
            vm.addr(1337),
            tokenId
        );

        address vaultAddress = vaultRegistry.deployVault(
            vm.addr(1337),
            tokenId
        );

        assertTrue(vaultAddress != address(0));
        assertTrue(vaultAddress == predictedVaultAddress);
    }
}
