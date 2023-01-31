// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/interfaces/IRegistry.sol";
import "../src/lib/MinimalProxyStore.sol";
import "../src/CrossChainExecutorList.sol";
import "../src/Account.sol";
import "../src/AccountRegistry.sol";

contract AccountRegistryTest is Test {
    CrossChainExecutorList ccExecutorList;
    Account implementation;
    AccountRegistry public accountRegistry;

    event AccountCreated(
        address account,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    function setUp() public {
        ccExecutorList = new CrossChainExecutorList();
        implementation = new Account(address(ccExecutorList));
        accountRegistry = new AccountRegistry(address(implementation));
    }

    function testDeployAccount(address tokenCollection, uint256 tokenId)
        public
    {
        assertTrue(address(accountRegistry) != address(0));

        address predictedAccountAddress = accountRegistry.account(
            tokenCollection,
            tokenId
        );

        vm.expectEmit(true, true, true, true);
        emit AccountCreated(predictedAccountAddress, tokenCollection, tokenId);
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
