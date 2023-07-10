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
import "../src/AccountProxy.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockExecutor.sol";
import "./mocks/MockReverter.sol";
import "./mocks/MockAccount.sol";

contract AccountTest is Test {
    Account implementation;
    ERC6551Registry public registry;
    AccountGuardian public guardian;
    AccountProxy public proxy;
    IEntryPoint public entryPoint;

    MockERC721 public tokenCollection;

    function setUp() public {
        entryPoint = new EntryPoint();
        guardian = new AccountGuardian();
        implementation = new Account(address(guardian), address(entryPoint));
        proxy = new AccountProxy(address(implementation));

        registry = new ERC6551Registry();

        tokenCollection = new MockERC721();
    }

    function testNonOwnerCallsFail(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.executeCall(payable(user2), 0.1 ether, "");

        // should fail if user2 tries to set override
        address[] memory callers = new address[](1);
        callers[0] = vm.addr(1337);
        bool[] memory _permissions = new bool[](1);
        _permissions[0] = true;
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.setPermissions(callers, _permissions);

        // should fail if user2 tries to lock account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.lock(364 days);
    }

    function testAccountOwnershipTransfer(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.executeCall(payable(user2), 0.1 ether, "");

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, user2, tokenId);

        // should succeed now that user2 is owner
        vm.prank(user2);
        account.executeCall(payable(user2), 0.1 ether, "");

        assertEq(user2.balance, 0.1 ether);
    }

    function testMessageVerification(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        Account account = Account(payable(accountAddress));

        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, hash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        bytes4 returnValue1 = account.isValidSignature(hash, signature1);

        assertEq(returnValue1, IERC1271.isValidSignature.selector);
    }

    function testMessageVerificationForUnauthorizedUser(uint256 tokenId)
        public
    {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
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

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        // cannot be locked for more than 365 days
        vm.prank(user1);
        vm.expectRevert(ExceedsMaxLockTime.selector);
        account.lock(366 days);

        // lock account for 10 days
        uint256 unlockTimestamp = block.timestamp + 10 days;
        vm.prank(user1);
        account.lock(unlockTimestamp);

        assertEq(account.isLocked(), true);

        // transaction should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(AccountLocked.selector);
        account.executeCall(payable(user1), 1 ether, "");

        // fallback calls should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(AccountLocked.selector);
        (bool success, bytes memory result) = accountAddress.call(
            abi.encodeWithSignature("customFunction()")
        );

        // silence unused variable compiler warnings
        success;
        result;

        // setOverrides calls should revert if account is locked
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = Account.executeCall.selector;
            address[] memory implementations = new address[](1);
            implementations[0] = vm.addr(1337);
            vm.prank(user1);
            vm.expectRevert(AccountLocked.selector);
            account.setOverrides(selectors, implementations);
        }

        // lock calls should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(AccountLocked.selector);
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

    function testCustomOverridesFallback(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // calls succeed with noop if override is undefined
        (bool success, bytes memory result) = accountAddress.call(
            abi.encodeWithSignature("customFunction()")
        );
        assertEq(success, true);
        assertEq(result, "");

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(abi.encodeWithSignature("customFunction()"));
        selectors[1] = bytes4(abi.encodeWithSignature("fail()"));
        address[] memory implementations = new address[](2);
        implementations[0] = address(mockExecutor);
        implementations[1] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        // execution module handles fallback calls
        assertEq(MockExecutor(accountAddress).customFunction(), 12345);

        // execution bubbles up errors on revert
        vm.expectRevert(MockReverter.MockError.selector);
        MockExecutor(accountAddress).fail();
    }

    function testCustomOverridesSupportsInterface(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        assertEq(
            account.supportsInterface(type(IERC1155Receiver).interfaceId),
            true
        );
        assertEq(account.supportsInterface(0x12345678), false);

        MockExecutor mockExecutor = new MockExecutor();

        // set overrides on account
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(
            abi.encodeWithSignature("supportsInterface(bytes4)")
        );
        address[] memory implementations = new address[](1);
        implementations[0] = address(mockExecutor);
        vm.prank(user1);
        account.setOverrides(selectors, implementations);

        // override handles extra interface support
        assertEq(
            Account(payable(accountAddress)).supportsInterface(0x12345678),
            true
        );
        // cannot override default interfaces
        assertEq(
            Account(payable(accountAddress)).supportsInterface(
                type(IERC1155Receiver).interfaceId
            ),
            true
        );
    }

    /**/
    function testCustomPermissions(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        assertEq(account.isAuthorized(user2), false);

        address[] memory callers = new address[](1);
        callers[0] = address(user2);
        bool[] memory _permissions = new bool[](1);
        _permissions[0] = true;
        vm.prank(user1);
        account.setPermissions(callers, _permissions);

        assertEq(account.isAuthorized(user2), true);

        vm.prank(user2);
        account.executeCall(user2, 0.1 ether, "");

        assertEq(user2.balance, 0.1 ether);
    }

    function testCrossChainCalls() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address crossChainExecutor = vm.addr(2);

        uint256 chainId = block.chainid + 1;

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            chainId,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        assertEq(account.isAuthorized(crossChainExecutor), false);

        guardian.setTrustedExecutor(crossChainExecutor, true);

        assertEq(account.isAuthorized(crossChainExecutor), true);

        vm.prank(crossChainExecutor);
        account.executeCall(user1, 0.1 ether, "");

        assertEq(user1.balance, 0.1 ether);

        address notCrossChainExecutor = vm.addr(3);
        vm.prank(notCrossChainExecutor);
        vm.expectRevert(NotAuthorized.selector);
        Account(payable(account)).executeCall(user1, 0.1 ether, "");

        assertEq(user1.balance, 0.1 ether);

        address nativeAccountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.prank(crossChainExecutor);
        vm.expectRevert(NotAuthorized.selector);
        Account(payable(nativeAccountAddress)).executeCall(
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

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
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
        address accountClone = Clones.clone(address(implementation));

        assertEq(Account(payable(accountClone)).owner(), address(0));
    }

    function testEIP165Support() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        assertEq(
            account.supportsInterface(type(IERC6551Account).interfaceId),
            true
        );
        assertEq(
            account.supportsInterface(type(IERC1155Receiver).interfaceId),
            true
        );
        assertEq(account.supportsInterface(type(IERC165).interfaceId), true);
    }

    function testAccountUpgrade() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(
            address(proxy),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        Account account = Account(payable(accountAddress));

        MockAccount upgradedImplementation = new MockAccount(
            address(guardian),
            address(entryPoint)
        );

        vm.expectRevert(UntrustedImplementation.selector);
        vm.prank(user1);
        account.upgradeTo(address(upgradedImplementation));

        guardian.setTrustedImplementation(
            address(upgradedImplementation),
            true
        );

        vm.prank(user1);
        account.upgradeTo(address(upgradedImplementation));
        uint256 returnValue = MockAccount(payable(accountAddress))
            .customFunction();

        assertEq(returnValue, 12345);
    }

    function testProxyZeroAddressInit() public {
        vm.expectRevert(InvalidImplementation.selector);
        new AccountProxy(address(0));
    }
}
