// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "erc6551/ERC6551Registry.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/interfaces/IERC6551Executable.sol";

import "../src/AccountV3.sol";
import "../src/AccountV3Upgradable.sol";
import "../src/AccountGuardian.sol";
import "../src/AccountProxy.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockSigner.sol";
import "./mocks/MockExecutor.sol";
import "./mocks/MockSandboxExecutor.sol";
import "./mocks/MockReverter.sol";
import "./mocks/MockAccountUpgradable.sol";

contract AccountTest is Test {
    AccountV3 implementation;
    ERC6551Registry public registry;

    MockERC721 public tokenCollection;

    function setUp() public {
        registry = new ERC6551Registry();

        implementation = new AccountV3(address(1), address(1), address(registry), address(1));

        tokenCollection = new MockERC721();

        // mint tokenId 1 during setup for accurate cold call gas measurement
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        tokenCollection.mint(user1, tokenId);
    }

    function testCustomPermissions() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        assertTrue(account.isValidSigner(user2, "") != IERC6551Account.isValidSigner.selector);

        address[] memory callers = new address[](1);
        callers[0] = address(user2);
        bool[] memory _permissions = new bool[](1);
        _permissions[0] = true;
        vm.prank(user1);
        account.setPermissions(callers, _permissions);

        assertEq(account.isValidSigner(user2, ""), IERC6551Account.isValidSigner.selector);

        vm.prank(user2);
        account.execute(user2, 0.1 ether, "", 0);

        assertEq(user2.balance, 0.1 ether);
    }

    function testCustomPermissionsNested() public {
        uint256 tokenId = 1;
        uint256 tokenId2 = 2;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(accountAddress, tokenId2);

        address accountAddress2 = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId2
        );

        vm.deal(accountAddress2, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress2));

        assertTrue(account.isValidSigner(user2, "") != IERC6551Account.isValidSigner.selector);

        address[] memory callers = new address[](1);
        callers[0] = address(user2);
        bool[] memory _permissions = new bool[](1);
        _permissions[0] = true;
        vm.prank(user1);
        account.setPermissions(callers, _permissions);

        assertEq(account.isValidSigner(user2, ""), IERC6551Account.isValidSigner.selector);

        vm.prank(user2);
        account.execute(user2, 0.1 ether, "", 0);

        assertEq(user2.balance, 0.1 ether);

        // Permissions should reset when root token is transferred
        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, vm.addr(3), tokenId);
        assertTrue(account.isValidSigner(user2, "") != IERC6551Account.isValidSigner.selector);
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(user2, 0.1 ether, "", 0);
    }
}
