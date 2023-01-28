// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "../src/CrossChainExecutorList.sol";
import "../src/Account.sol";
import "../src/AccountRegistry.sol";

import "./mocks/MockERC721.sol";

contract AccountTest is Test {
    CrossChainExecutorList ccExecutorList;
    Account implementation;
    AccountRegistry public accountRegistry;

    MockERC721 public tokenCollection;

    function setUp() public {
        ccExecutorList = new CrossChainExecutorList();
        implementation = new Account(address(ccExecutorList));
        accountRegistry = new AccountRegistry(address(implementation));

        tokenCollection = new MockERC721();
    }

    function testTransferETHPreDeploy() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        // get address that account will be deployed to (before token is minted)
        address accountAddress = accountRegistry.account(
            address(tokenCollection),
            tokenId
        );

        // mint token for account to user1
        tokenCollection.mint(user1, tokenId);

        assertEq(tokenCollection.ownerOf(tokenId), user1);

        // send ETH from user1 to account (prior to account deployment)
        vm.prank(user1);
        (bool sent, ) = accountAddress.call{value: 0.2 ether}("");
        assertTrue(sent);

        assertEq(accountAddress.balance, 0.2 ether);

        // deploy account contract (from a different wallet)
        address createdAccountInstance = accountRegistry.createAccount(
            address(tokenCollection),
            tokenId
        );

        assertEq(accountAddress, createdAccountInstance);

        Account account = Account(payable(accountAddress));

        // user1 executes transaction to send ETH from account
        vm.prank(user1);
        account.executeCall(payable(user1), 0.1 ether, "");

        // success!
        assertEq(accountAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function testTransferETHPostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        address accountAddress = accountRegistry.createAccount(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);

        assertEq(tokenCollection.ownerOf(tokenId), user1);

        vm.prank(user1);
        (bool sent, ) = accountAddress.call{value: 0.2 ether}("");
        assertTrue(sent);

        assertEq(accountAddress.balance, 0.2 ether);

        Account account = Account(payable(accountAddress));

        vm.prank(user1);
        account.executeCall(payable(user1), 0.1 ether, "");

        assertEq(accountAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }
}
