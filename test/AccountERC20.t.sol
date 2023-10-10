// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "erc6551/ERC6551Registry.sol";
import "erc6551/interfaces/IERC6551Account.sol";

import "../src/AccountV3.sol";
import "../src/AccountGuardian.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockERC20.sol";

contract AccountERC20Test is Test {
    MockERC20 public dummyERC20;

    AccountV3 implementation;
    ERC6551Registry public registry;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC20 = new MockERC20();

        implementation = new AccountV3(address(1), address(1), address(1), address(1));
        registry = new ERC6551Registry();

        tokenCollection = new MockERC721();
    }

    function testTransferERC20PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = registry.account(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(computedAccountInstance, 1 ether);

        assertEq(dummyERC20.balanceOf(computedAccountInstance), 1 ether);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 account = AccountV3(payable(accountAddress));

        bytes memory erc20TransferCall =
            abi.encodeWithSignature("transfer(address,uint256)", user1, 1 ether);
        vm.prank(user1);
        account.execute(payable(address(dummyERC20)), 0, erc20TransferCall, 0);

        assertEq(dummyERC20.balanceOf(accountAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }

    function testTransferERC20PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(accountAddress, 1 ether);

        assertEq(dummyERC20.balanceOf(accountAddress), 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        bytes memory erc20TransferCall =
            abi.encodeWithSignature("transfer(address,uint256)", user1, 1 ether);
        vm.prank(user1);
        account.execute(payable(address(dummyERC20)), 0, erc20TransferCall, 0);

        assertEq(dummyERC20.balanceOf(accountAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }
}
