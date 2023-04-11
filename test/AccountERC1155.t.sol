// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "../src/CrossChainExecutorList.sol";
import "../src/Account.sol";
import "../src/AccountRegistry.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockERC1155.sol";

contract AccountTest is Test {
    MockERC1155 public dummyERC1155;

    CrossChainExecutorList ccExecutorList;
    Account implementation;
    AccountRegistry public accountRegistry;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC1155 = new MockERC1155();

        ccExecutorList = new CrossChainExecutorList();
        implementation = new Account(address(ccExecutorList));
        accountRegistry = new AccountRegistry(address(implementation));

        tokenCollection = new MockERC721();
    }

    function testTransferERC1155PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = accountRegistry.account(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(computedAccountInstance, 1, 10);

        assertEq(dummyERC1155.balanceOf(computedAccountInstance, 1), 10);

        address accountAddress = accountRegistry.createAccount(
            address(tokenCollection),
            tokenId
        );

        Account account = Account(payable(accountAddress));

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            account,
            user1,
            1,
            10,
            ""
        );
        vm.prank(user1);
        account.executeCall(
            payable(address(dummyERC1155)),
            0,
            erc1155TransferCall
        );

        assertEq(dummyERC1155.balanceOf(accountAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }

    function testTransferERC1155PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address accountAddress = accountRegistry.createAccount(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(accountAddress, 1, 10);

        assertEq(dummyERC1155.balanceOf(accountAddress, 1), 10);

        Account account = Account(payable(accountAddress));

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            account,
            user1,
            1,
            10,
            ""
        );
        vm.prank(user1);
        account.executeCall(
            payable(address(dummyERC1155)),
            0,
            erc1155TransferCall
        );

        assertEq(dummyERC1155.balanceOf(accountAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }
}
