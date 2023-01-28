// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Account.sol";
import "../src/AccountRegistry.sol";
import "../src/lib/MinimalProxyStore.sol";

contract AccountRegistryTest is Test {
    AccountRegistry public accountRegistry;

    function setUp() public {
        accountRegistry = new AccountRegistry();
    }

    function testDeployAccount(address tokenCollection, uint256 tokenId)
        public
    {
        assertTrue(address(accountRegistry) != address(0));

        address predictedAccountAddress = accountRegistry.account(
            tokenCollection,
            tokenId
        );

        address accountAddress = accountRegistry.createAccount(
            tokenCollection,
            tokenId
        );

        assertTrue(accountAddress != address(0));
        assertTrue(accountAddress == predictedAccountAddress);
        assertEq(
            MinimalProxyStore.getContext(accountAddress),
            abi.encode(block.chainid, tokenCollection, tokenId)
        );
    }
}
