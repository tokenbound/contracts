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
import "./mocks/MockERC1155.sol";
import "./mocks/MockExecutor.sol";

contract AccountERC1155Test is Test {
    MockERC1155 public dummyERC1155;

    AccountV3 implementation;
    ERC6551Registry public registry;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC1155 = new MockERC1155();

        implementation = new AccountV3(address(1), address(1), address(1), address(1));
        registry = new ERC6551Registry();

        tokenCollection = new MockERC721();
    }

    function testTransferERC1155PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = registry.account(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(computedAccountInstance, 1, 10);

        assertEq(dummyERC1155.balanceOf(computedAccountInstance, 1), 10);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 account = AccountV3(payable(accountAddress));

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)", account, user1, 1, 10, ""
        );
        vm.prank(user1);
        account.execute(payable(address(dummyERC1155)), 0, erc1155TransferCall, 0);

        assertEq(dummyERC1155.balanceOf(accountAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }

    function testTransferERC1155PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(accountAddress, 1, 10);

        assertEq(dummyERC1155.balanceOf(accountAddress, 1), 10);

        AccountV3 account = AccountV3(payable(accountAddress));

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)", account, user1, 1, 10, ""
        );
        vm.prank(user1);
        account.execute(payable(address(dummyERC1155)), 0, erc1155TransferCall, 0);

        assertEq(dummyERC1155.balanceOf(accountAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }

    function testBatchTransferERC1155(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(user1, 1, 10);
        dummyERC1155.mint(user1, 2, 10);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 10;

        vm.prank(user1);
        dummyERC1155.safeBatchTransferFrom(user1, accountAddress, ids, amounts, "");

        assertEq(dummyERC1155.balanceOf(accountAddress, 1), 10);
        assertEq(dummyERC1155.balanceOf(accountAddress, 2), 10);
        assertEq(dummyERC1155.balanceOf(user1, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 2), 0);
    }

    function testOverrideERC1155Receiver(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 account = AccountV3(payable(accountAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(
            abi.encodeWithSignature("onERC1155Received(address,address,uint256,uint256,bytes)")
        );
        address[] memory implementations = new address[](1);
        implementations[0] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        vm.expectRevert("ERC1155: ERC1155Receiver rejected tokens");
        dummyERC1155.mint(accountAddress, 1, 10);
    }

    function testOverrideERC1155BatchReceiver(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 account = AccountV3(payable(accountAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(
            abi.encodeWithSignature(
                "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
            )
        );
        address[] memory implementations = new address[](1);
        implementations[0] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        dummyERC1155.mint(user1, 1, 10);
        dummyERC1155.mint(user1, 2, 10);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 10;

        vm.expectRevert("ERC1155: ERC1155Receiver rejected tokens");
        vm.prank(user1);
        dummyERC1155.safeBatchTransferFrom(user1, accountAddress, ids, amounts, "");
    }
}
