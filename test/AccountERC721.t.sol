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
import "./mocks/MockExecutor.sol";

contract AccountERC721Test is Test {
    MockERC721 public dummyERC721;

    Account implementation;
    AccountGuardian public guardian;
    ERC6551Registry public registry;
    IEntryPoint public entryPoint;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC721 = new MockERC721();

        entryPoint = new EntryPoint();
        guardian = new AccountGuardian();
        implementation = new Account(address(guardian), address(entryPoint));
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

    function testCannotOwnSelf() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;
        uint256 salt = 200;

        tokenCollection.mint(owner, tokenId);

        vm.prank(owner, owner);
        address account = registry.createAccount(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            salt,
            ""
        );

        vm.prank(owner);
        vm.expectRevert(OwnershipCycle.selector);
        tokenCollection.safeTransferFrom(owner, account, tokenId);
    }

    function testExceedsOwnershipDepthLimit() public {
        uint256 count = 7;
        address[] memory owners = new address[](count);
        address[] memory accounts = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = i + 1;
            owners[i] = vm.addr(tokenId);
            tokenCollection.mint(owners[i], tokenId);
            accounts[i] = registry.createAccount(
                address(implementation),
                block.chainid,
                address(tokenCollection),
                tokenId,
                0,
                ""
            );
        }

        for (uint256 i = 0; i < count - 1; i++) {
            uint256 tokenId = i + 1;
            vm.prank(owners[i]);
            tokenCollection.safeTransferFrom(
                owners[i],
                accounts[i + 1],
                tokenId
            );
        }

        // Executes without error because cycle protection max depth has been exceeded
        vm.prank(owners[6]);
        tokenCollection.safeTransferFrom(owners[6], accounts[0], 7);
    }

    function testOverrideERC721Receiver(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            ""
        );

        Account account = Account(payable(accountAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(
            abi.encodeWithSignature(
                "onERC721Received(address,address,uint256,bytes)"
            )
        );
        address[] memory implementations = new address[](1);
        implementations[0] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        vm.expectRevert("ERC721: transfer to non ERC721Receiver implementer");
        dummyERC721.mint(accountAddress, 1);
    }
}
