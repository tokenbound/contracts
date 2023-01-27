// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "../src/Account.sol";
import "../src/AccountRegistry.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockERC1155.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockExecutor.sol";
import "./mocks/MockReverter.sol";

contract AccountTest is Test {
    MockERC721 public dummyERC721;
    MockERC1155 public dummyERC1155;
    MockERC20 public dummyERC20;

    AccountRegistry public accountRegistry;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC721 = new MockERC721();
        dummyERC1155 = new MockERC1155();
        dummyERC20 = new MockERC20();
        accountRegistry = new AccountRegistry();

        tokenCollection = new MockERC721();
    }

    function testTransferETHPreDeploy() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        // get address that account will be deployed to (before token is minted)
        address accountAddress = accountRegistry.accountAddress(
            address(tokenCollection),
            tokenId
        );

        // mint token for account to user1
        tokenCollection.mint(user1, tokenId);

        assertEq(tokenCollection.ownerOf(tokenId), user1);

        // send ETH from user1 to account (prior to account deployment)
        vm.prank(user1);
        (bool sent, ) = accountAddress.call{value: 0.2 ether}("");
        assertTrue(sent);

        assertEq(accountAddress.balance, 0.2 ether);

        // deploy account contract (from a different wallet)
        address createdAccountInstance = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        assertEq(accountAddress, createdAccountInstance);

        Account account = Account(payable(accountAddress));

        // user1 executes transaction to send ETH from account
        vm.prank(user1);
        account.executeCall(payable(user1), 0.1 ether, "");

        // success!
        assertEq(accountAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function testTransferETHPostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);

        assertEq(tokenCollection.ownerOf(tokenId), user1);

        vm.prank(user1);
        (bool sent, ) = accountAddress.call{value: 0.2 ether}("");
        assertTrue(sent);

        assertEq(accountAddress.balance, 0.2 ether);

        Account account = Account(payable(accountAddress));

        vm.prank(user1);
        account.executeCall(payable(user1), 0.1 ether, "");

        assertEq(accountAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function testTransferERC20PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = accountRegistry.accountAddress(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(computedAccountInstance, 1 ether);

        assertEq(dummyERC20.balanceOf(computedAccountInstance), 1 ether);

        address accountAddress = accountRegistry.deployAccount(
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

        address accountAddress = accountRegistry.deployAccount(
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

    function testTransferERC1155PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = accountRegistry.accountAddress(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(computedAccountInstance, 1, 10);

        assertEq(dummyERC1155.balanceOf(computedAccountInstance, 1), 10);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        Account account = Account(payable(accountAddress));

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            accountAddress,
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

        address accountAddress = accountRegistry.deployAccount(
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
            accountAddress,
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

    function testTransferERC721PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedAccountInstance = accountRegistry.accountAddress(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC721.mint(computedAccountInstance, 1);

        assertEq(dummyERC721.balanceOf(computedAccountInstance), 1);
        assertEq(dummyERC721.ownerOf(1), computedAccountInstance);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        Account account = Account(payable(accountAddress));

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(accountAddress),
            user1,
            1
        );
        vm.prank(user1);
        account.executeCall(
            payable(address(dummyERC721)),
            0,
            erc721TransferCall
        );

        assertEq(dummyERC721.balanceOf(address(accountAddress)), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }

    function testTransferERC721PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC721.mint(accountAddress, 1);

        assertEq(dummyERC721.balanceOf(accountAddress), 1);
        assertEq(dummyERC721.ownerOf(1), accountAddress);

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

        assertEq(dummyERC721.balanceOf(accountAddress), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }

    function testNonOwnerCallsFail(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(Account.NotAuthorized.selector);
        account.executeCall(payable(user2), 0.1 ether, "");

        // should fail if user2 tries to set executor
        vm.prank(user2);
        vm.expectRevert(Account.NotAuthorized.selector);
        account.setExecutor(vm.addr(1337));

        // should fail if user2 tries to lock account
        vm.prank(user2);
        vm.expectRevert(Account.NotAuthorized.selector);
        account.lock(364 days);
    }

    function testAccountOwnershipTransfer(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(Account.NotAuthorized.selector);
        account.executeCall(payable(user2), 0.1 ether, "");

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, user2, tokenId);

        // should succeed now that user2 is owner
        vm.prank(user2);
        account.executeCall(payable(user2), 0.1 ether, "");

        assertEq(user2.balance, 0.1 ether);
    }

    function testMessageSigningAndVerificationForAuthorizedUser(uint256 tokenId)
        public
    {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        Account account = Account(payable(accountAddress));

        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, hash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        bytes4 returnValue1 = account.isValidSignature(hash, signature1);

        assertEq(returnValue1, IERC1271.isValidSignature.selector);
    }

    function testMessageSigningAndVerificationForUnauthorizedUser(
        uint256 tokenId
    ) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        Account account = Account(payable(accountAddress));

        bytes32 hash = keccak256("This is a signed message");

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(2, hash);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes4 returnValue2 = account.isValidSignature(hash, signature2);

        assertEq(returnValue2, 0);
    }

    function testAccountLocksAndUnlocks(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        // cannot be locked for more than 365 days
        vm.prank(user1);
        vm.expectRevert(Account.ExceedsMaxLockTime.selector);
        account.lock(366 days);

        // lock account for 10 days
        uint256 unlockTimestamp = block.timestamp + 10 days;
        vm.prank(user1);
        account.lock(unlockTimestamp);

        assertEq(account.isLocked(), true);

        // transaction should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(Account.AccountLocked.selector);
        account.executeCall(payable(user1), 1 ether, "");

        // fallback calls should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(Account.AccountLocked.selector);
        (bool success, bytes memory result) = accountAddress.call(
            abi.encodeWithSignature("customFunction()")
        );

        // silence unused variable compiler warnings
        success;
        result;

        // setExecutor calls should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(Account.AccountLocked.selector);
        account.setExecutor(vm.addr(1337));

        // lock calls should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(Account.AccountLocked.selector);
        account.lock(0);

        // signing should fail if account is locked
        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(2, hash);
        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes4 returnValue = account.isValidSignature(hash, signature1);
        assertEq(returnValue, 0);

        // warp to timestamp after account is unlocked
        vm.warp(unlockTimestamp + 1 days);

        // transaction succeed now that account lock has expired
        vm.prank(user1);
        account.executeCall(payable(user1), 1 ether, "");
        assertEq(user1.balance, 1 ether);

        // signing should now that account lock has expired
        bytes32 hashAfterUnlock = keccak256("This is a signed message");
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(1, hashAfterUnlock);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);
        bytes4 returnValue1 = account.isValidSignature(
            hashAfterUnlock,
            signature2
        );
        assertEq(returnValue1, IERC1271.isValidSignature.selector);
    }

    function testCustomExecutorFallback(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // calls succeed with noop if executor is undefined
        (bool success, bytes memory result) = accountAddress.call(
            abi.encodeWithSignature("customFunction()")
        );
        assertEq(success, true);
        assertEq(result, "");

        // calls succeed with noop if executor is EOA
        vm.prank(user1);
        account.setExecutor(vm.addr(1337));
        (bool success1, bytes memory result1) = accountAddress.call(
            abi.encodeWithSignature("customFunction()")
        );
        assertEq(success1, true);
        assertEq(result1, "");

        assertEq(account.isAuthorized(user1), true);
        assertEq(account.isAuthorized(address(mockExecutor)), false);

        vm.prank(user1);
        account.setExecutor(address(mockExecutor));

        assertEq(account.isAuthorized(user1), true);
        assertEq(account.isAuthorized(address(mockExecutor)), true);

        assertEq(
            account.isValidSignature(bytes32(0), ""),
            IERC1271.isValidSignature.selector
        );

        // execution module handles fallback calls
        assertEq(MockExecutor(accountAddress).customFunction(), 12345);

        // execution bubbles up errors on revert
        vm.expectRevert(MockReverter.MockError.selector);
        MockExecutor(accountAddress).fail();
    }

    function testCustomExecutorCalls(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        assertEq(account.isAuthorized(user2), false);

        vm.prank(user1);
        account.setExecutor(user2);

        assertEq(account.isAuthorized(user2), true);

        vm.prank(user2);
        account.executeTrustedCall(user2, 0.1 ether, "");

        assertEq(user2.balance, 0.1 ether);
    }

    function testCrossChainCalls() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address crossChainExecutor = vm.addr(2);

        uint256 chainId = block.chainid + 1;

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            chainId,
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        assertEq(account.isAuthorized(crossChainExecutor), false);

        accountRegistry.setCrossChainExecutor(
            chainId,
            crossChainExecutor,
            true
        );

        assertEq(account.isAuthorized(crossChainExecutor), true);

        vm.prank(crossChainExecutor);
        account.executeCrossChainCall(user1, 0.1 ether, "");

        assertEq(user1.balance, 0.1 ether);

        address notCrossChainExecutor = vm.addr(3);
        vm.prank(notCrossChainExecutor);
        vm.expectRevert(Account.NotAuthorized.selector);
        Account(payable(accountAddress)).executeCrossChainCall(
            user1,
            0.1 ether,
            ""
        );

        assertEq(user1.balance, 0.1 ether);

        address nativeAccountAddress = accountRegistry.deployAccount(
            block.chainid,
            address(tokenCollection),
            tokenId
        );

        vm.prank(crossChainExecutor);
        vm.expectRevert(Account.NotAuthorized.selector);
        Account(payable(nativeAccountAddress)).executeCrossChainCall(
            user1,
            0.1 ether,
            ""
        );

        assertEq(user1.balance, 0.1 ether);
    }

    function testExecuteCallRevert(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        MockReverter mockReverter = new MockReverter();

        vm.prank(user1);
        vm.expectRevert(MockReverter.MockError.selector);
        account.executeCall(
            payable(address(mockReverter)),
            0,
            abi.encodeWithSignature("fail()")
        );
    }

    function testAccountOwnerIsNullIfContextNotSet() public {
        address accountClone = Clones.clone(
            accountRegistry.defaultImplementation()
        );

        assertEq(Account(payable(accountClone)).owner(), address(0));
    }

    function testEIP165Support() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = accountRegistry.deployAccount(
            address(tokenCollection),
            tokenId
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        assertEq(account.supportsInterface(type(IAccount).interfaceId), true);
        assertEq(
            account.supportsInterface(type(IERC1155Receiver).interfaceId),
            true
        );
        assertEq(account.supportsInterface(type(IERC165).interfaceId), true);
        assertEq(
            account.supportsInterface(IERC1271.isValidSignature.selector),
            false
        );

        MockExecutor mockExecutor = new MockExecutor();

        vm.prank(user1);
        account.setExecutor(address(mockExecutor));

        assertEq(
            account.supportsInterface(IERC1271.isValidSignature.selector),
            true
        );
    }
}
