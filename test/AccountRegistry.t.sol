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

        address predictedAccountAddress = accountRegistry.accountAddress(
            tokenCollection,
            tokenId
        );

        address accountAddress = accountRegistry.deployAccount(
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

    function testSetCrossChainExecutor() public {
        address crossChainExecutor = vm.addr(1);
        address notCrossChainExecutor = vm.addr(2);

        accountRegistry.setCrossChainExecutor(
            block.chainid,
            crossChainExecutor,
            true
        );

        assertTrue(
            accountRegistry.isCrossChainExecutor(
                block.chainid,
                crossChainExecutor
            )
        );
        assertEq(
            accountRegistry.isCrossChainExecutor(
                block.chainid,
                notCrossChainExecutor
            ),
            false
        );

        accountRegistry.setCrossChainExecutor(
            block.chainid,
            crossChainExecutor,
            false
        );
        assertEq(
            accountRegistry.isCrossChainExecutor(
                block.chainid,
                crossChainExecutor
            ),
            false
        );
    }
}
