// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "account-abstraction/core/EntryPoint.sol";

import "erc6551/ERC6551Registry.sol";
import "erc6551/interfaces/IERC6551Account.sol";

import "../src/Account.sol";
import "../src/AccountGuardian.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockERC20.sol";

contract AccountERC20Test is Test {
    MockERC20 public dummyERC20;

    Account implementation;
    AccountGuardian public guardian;
    ERC6551Registry public registry;
    IEntryPoint public entryPoint;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC20 = new MockERC20();

        entryPoint = new EntryPoint();
        guardian = new AccountGuardian();
        implementation = new Account(address(guardian), address(entryPoint));
        registry = new ERC6551Registry();

        tokenCollection = new MockERC721();
    }

    function testTransferERC20PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = registry.account(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(computedAccountInstance, 1 ether);

        assertEq(dummyERC20.balanceOf(computedAccountInstance), 1 ether);

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            ""
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

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            ""
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
