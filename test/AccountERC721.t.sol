// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "erc6551/ERC6551Registry.sol";
import "erc6551/interfaces/IERC6551Account.sol";

import "../src/Account.sol";
import "../src/AccountGuardian.sol";

import "./mocks/MockERC721.sol";

contract AccountERC721Test is Test {
    MockERC721 public dummyERC721;

    Account implementation;
    AccountGuardian public guardian;
    ERC6551Registry public registry;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC721 = new MockERC721();

        guardian = new AccountGuardian();
        implementation = new Account(address(guardian), address(0));
        registry = new ERC6551Registry();

        tokenCollection = new MockERC721();
    }

    function testTransferERC721PreDeploy(uint256 tokenId) public {
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

        dummyERC721.mint(computedAccountInstance, 1);

        assertEq(dummyERC721.balanceOf(computedAccountInstance), 1);
        assertEq(dummyERC721.ownerOf(1), computedAccountInstance);

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            ""
        );

        Account account = Account(payable(accountAddress));

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            accountAddress,
            user1,
            1
        );
        vm.prank(user1);
        account.executeCall(
            payable(address(dummyERC721)),
            0,
            erc721TransferCall
        );

        assertEq(dummyERC721.balanceOf(address(account)), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }

    function testTransferERC721PostDeploy(uint256 tokenId) public {
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

        dummyERC721.mint(accountAddress, 1);

        assertEq(dummyERC721.balanceOf(accountAddress), 1);
        assertEq(dummyERC721.ownerOf(1), accountAddress);

        Account account = Account(payable(accountAddress));

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            account,
            user1,
            1
        );
        vm.prank(user1);
        account.executeCall(
            payable(address(dummyERC721)),
            0,
            erc721TransferCall
        );

        assertEq(dummyERC721.balanceOf(accountAddress), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }
}
