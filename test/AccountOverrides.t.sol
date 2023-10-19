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

    function testCustomOverridesFallback() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // calls succeed with noop if override is undefined
        (bool success, bytes memory result) =
            accountAddress.call(abi.encodeWithSignature("customFunction()"));
        assertEq(success, true);
        assertEq(result, "");

        uint256 state = account.state();

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(abi.encodeWithSignature("customFunction()"));
        selectors[1] = bytes4(abi.encodeWithSignature("fail()"));
        address[] memory implementations = new address[](2);
        implementations[0] = address(mockExecutor);
        implementations[1] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        assertTrue(state != account.state());

        // execution module handles fallback calls
        assertEq(MockExecutor(accountAddress).customFunction(), 12345);

        // execution bubbles up errors on revert
        vm.expectRevert(MockReverter.MockError.selector);
        MockExecutor(accountAddress).fail();
    }

    function testCustomOverridesSupportsInterface() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        assertEq(account.supportsInterface(type(IERC1155Receiver).interfaceId), true);
        assertEq(account.supportsInterface(0x12345678), false);

        MockExecutor mockExecutor = new MockExecutor();

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(abi.encodeWithSignature("supportsInterface(bytes4)"));
        address[] memory implementations = new address[](1);
        implementations[0] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        // override handles extra interface support
        assertEq(AccountV3(payable(accountAddress)).supportsInterface(0x12345678), true);
        // cannot override default interfaces
        assertEq(
            AccountV3(payable(accountAddress)).supportsInterface(type(IERC1155Receiver).interfaceId),
            true
        );
    }

    function testCustomOverridesNested() public {
        uint256 tokenId = 1;
        uint256 tokenId2 = 2;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(accountAddress, tokenId2);

        address accountAddress2 = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId2
        );

        vm.deal(accountAddress2, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress2));

        MockExecutor mockExecutor = new MockExecutor();

        // calls succeed with noop if override is undefined
        (bool success, bytes memory result) =
            accountAddress.call(abi.encodeWithSignature("customFunction()"));
        assertEq(success, true);
        assertEq(result, "");

        uint256 state = account.state();

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(abi.encodeWithSignature("customFunction()"));
        selectors[1] = bytes4(abi.encodeWithSignature("fail()"));
        address[] memory implementations = new address[](2);
        implementations[0] = address(mockExecutor);
        implementations[1] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        assertTrue(state != account.state());

        // execution module handles fallback calls
        assertEq(MockExecutor(accountAddress2).customFunction(), 12345);

        // execution bubbles up errors on revert
        vm.expectRevert(MockReverter.MockError.selector);
        MockExecutor(accountAddress2).fail();

        // overrides should be reset on root token transfer
        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, vm.addr(3), tokenId);
        (success, result) = accountAddress.call(abi.encodeWithSignature("customFunction()"));
        assertEq(success, true);
        assertEq(result, "");
        (success, result) = accountAddress.call(abi.encodeWithSignature("fail()"));
        assertEq(success, true);
        assertEq(result, "");
    }
}
