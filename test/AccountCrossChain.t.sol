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

import "../src/lib/OPAddressAliasHelper.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockSigner.sol";
import "./mocks/MockExecutor.sol";
import "./mocks/MockSandboxExecutor.sol";
import "./mocks/MockReverter.sol";
import "./mocks/MockAccountUpgradable.sol";

contract AccountTest is Test {
    AccountV3 implementation;
    AccountV3Upgradable upgradableImplementation;
    ERC6551Registry public registry;
    AccountGuardian public guardian;

    MockERC721 public tokenCollection;

    uint256 fork1;
    uint256 fork2;

    function setUp() public {
        fork1 = vm.createFork("https://ethereum.publicnode.com");
        fork2 = vm.createFork("https://optimism.publicnode.com");

        registry = new ERC6551Registry();

        guardian = new AccountGuardian(address(this));
        implementation = new AccountV3(address(1), address(1), address(registry), address(guardian));

        vm.makePersistent(address(registry));
        vm.makePersistent(address(guardian));
        vm.makePersistent(address(implementation));

        // collection only exists on fork1
        vm.selectFork(fork1);
        tokenCollection = new MockERC721();
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        tokenCollection.mint(user1, tokenId);
    }

    function testCrossChainCalls() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address crossChainExecutor = vm.addr(2);

        // create account on fork1
        vm.selectFork(fork1);
        assertEq(tokenCollection.ownerOf(tokenId), user1);
        uint256 chainId = block.chainid + 1;
        address accountAddress = registry.createAccount(
            address(implementation), 0, chainId, address(tokenCollection), tokenId
        );

        // create non-native account on fork2
        vm.selectFork(fork2);
        assertEq(address(tokenCollection).code.length, 0);
        assertFalse(chainId == block.chainid);
        registry.createAccount(
            address(implementation), 0, chainId, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        vm.prank(crossChainExecutor);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(user1, 0.1 ether, "", 0);
        assertEq(user1.balance, 0 ether);

        guardian.setTrustedExecutor(crossChainExecutor, true);

        vm.prank(crossChainExecutor);
        account.execute(user1, 0.1 ether, "", 0);
        assertEq(user1.balance, 0.1 ether);

        address notCrossChainExecutor = vm.addr(3);
        vm.prank(notCrossChainExecutor);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(user1, 0.1 ether, "", 0);
        assertEq(user1.balance, 0.1 ether);

        address nativeAccountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 nativeAccount = AccountV3(payable(nativeAccountAddress));

        vm.prank(crossChainExecutor);
        vm.expectRevert(NotAuthorized.selector);
        nativeAccount.execute(user1, 0.1 ether, "", 0);
        assertEq(user1.balance, 0.1 ether);
    }

    function testCrossChainCallsOPStack() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        // create account on fork1
        vm.selectFork(fork1);
        assertEq(tokenCollection.ownerOf(tokenId), user1);
        uint256 chainId = block.chainid + 1;
        address accountAddress = registry.createAccount(
            address(implementation), 0, chainId, address(tokenCollection), tokenId
        );

        // create non-native account on fork2
        vm.selectFork(fork2);
        assertEq(address(tokenCollection).code.length, 0);
        assertFalse(chainId == block.chainid);
        registry.createAccount(
            address(implementation), 0, chainId, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        // fork1 owner cannot access account
        vm.prank(vm.addr(1));
        vm.expectRevert(NotAuthorized.selector);
        account.execute(user1, 0.1 ether, "", 0);
        assertEq(user1.balance, 0 ether);

        // account can access account via optimism portal
        vm.prank(OPAddressAliasHelper.applyL1ToL2Alias(accountAddress));
        account.execute(user1, 0.1 ether, "", 0);
        assertEq(user1.balance, 0.1 ether);

        address nativeAccountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 nativeAccount = AccountV3(payable(nativeAccountAddress));

        // portal cannot be used to access native OP accounts
        vm.prank(OPAddressAliasHelper.applyL1ToL2Alias(accountAddress));
        vm.expectRevert(NotAuthorized.selector);
        nativeAccount.execute(user1, 0.1 ether, "", 0);
        assertEq(user1.balance, 0.1 ether);
    }
}
