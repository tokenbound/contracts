// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "../src/CrossChainExecutorList.sol";
import "../src/Account.sol";
import "../src/AccountRegistry.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockERC20.sol";

contract AccountTest is Test {
    MockERC20 public dummyERC20;

    CrossChainExecutorList ccExecutorList;
    Account implementation;
    AccountRegistry public accountRegistry;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC20 = new MockERC20();

        ccExecutorList = new CrossChainExecutorList();
        implementation = new Account(address(ccExecutorList));
        accountRegistry = new AccountRegistry(address(implementation));

        tokenCollection = new MockERC721();
    }

    function testTransferERC20PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = accountRegistry.account(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(computedAccountInstance, 1 ether);

        assertEq(dummyERC20.balanceOf(computedAccountInstance), 1 ether);

        address accountAddress = accountRegistry.createAccount(
            address(tokenCollection),
            tokenId
        );

        Account account = Account(payable(accountAddress));

        bytes memory erc20TransferCall = abi.encodeWithSignature(
            "transfer(address,uint256)",
            user1,
            1 ether
        );
        vm.prank(user1);
        account.executeCall(payable(address(dummyERC20)), 0, erc20TransferCall);

        assertEq(dummyERC20.balanceOf(accountAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }

    function testTransferERC20PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address accountAddress = accountRegistry.createAccount(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(accountAddress, 1 ether);

        assertEq(dummyERC20.balanceOf(accountAddress), 1 ether);

        Account account = Account(payable(accountAddress));

        bytes memory erc20TransferCall = abi.encodeWithSignature(
            "transfer(address,uint256)",
            user1,
            1 ether
        );
        vm.prank(user1);
        account.executeCall(payable(address(dummyERC20)), 0, erc20TransferCall);

        assertEq(dummyERC20.balanceOf(accountAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }
}
