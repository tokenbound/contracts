// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "erc6551/ERC6551Registry.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/interfaces/IERC6551Executable.sol";

import "../src/AccountV3.sol";
import "../src/AccountV3Upgradable.sol";
import "../src/AccountGuardian.sol";
import "../src/AccountProxy.sol";
import "../src/utils/MulticallForwarder.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockExecutor.sol";
import "./mocks/MockReverter.sol";
import "./mocks/MockAccountUpgradable.sol";

contract AccountTest is Test {
    MulticallForwarder forwarder;
    AccountV3 implementation;
    AccountV3Upgradable upgradableImplementation;
    AccountProxy proxy;
    ERC6551Registry public registry;
    AccountGuardian public guardian;

    MockERC721 public tokenCollection;

    function setUp() public {
        registry = new ERC6551Registry();

        forwarder = new MulticallForwarder();
        guardian = new AccountGuardian();
        implementation = new AccountV3(address(0), address(forwarder), address(registry));
        upgradableImplementation = new AccountV3Upgradable(address(0), address(0), address(0));
        proxy = new AccountProxy(address(upgradableImplementation));

        tokenCollection = new MockERC721();

        // mint tokenId 1 during setup for accurate cold call gas measurement
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        tokenCollection.mint(user1, tokenId);
    }

    function testNonOwnerCallsFail() public {
        uint256 tokenId = 1;
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(payable(user2), 0.1 ether, "", 0);

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(payable(user2), 0.1 ether, "", 0);
    }

    function testAccountOwnershipTransfer() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        // should succeed with original owner
        vm.prank(user1);
        account.execute(payable(user1), 0.1 ether, "", 0);

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(payable(user2), 0.1 ether, "", 0);

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, user2, tokenId);

        // should succeed now that user2 is owner
        vm.prank(user2);
        account.execute(payable(user2), 0.1 ether, "", 0);

        assertEq(user2.balance, 0.1 ether);
    }

    function testMessageVerification() public {
        uint256 tokenId = 1;

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        AccountV3 account = AccountV3(payable(accountAddress));

        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, hash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        bytes4 returnValue1 = account.isValidSignature(hash, signature1);

        assertEq(returnValue1, IERC1271.isValidSignature.selector);
    }

    function testMessageVerificationFailsInvalidSigner() public {
        uint256 tokenId = 1;

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        AccountV3 account = AccountV3(payable(accountAddress));

        bytes32 hash = keccak256("This is a signed message");

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(2, hash);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes4 returnValue2 = account.isValidSignature(hash, signature2);

        assertFalse(returnValue2 == IERC1271.isValidSignature.selector);
    }

    function testAccountLocksAndUnlocks() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        // cannot lock account if invalid signer
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.lock(1 days);

        // cannot be locked for more than 365 days
        vm.prank(user1);
        vm.expectRevert(ExceedsMaxLockTime.selector);
        account.lock(366 days);

        uint256 state = account.state();

        // lock account for 10 days
        uint256 unlockTimestamp = block.timestamp + 10 days;
        vm.prank(user1);
        account.lock(unlockTimestamp);

        // locking account should change state
        assertTrue(state != account.state());

        assertEq(account.isLocked(), true);

        // transaction should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(AccountLocked.selector);
        account.execute(payable(user1), 1 ether, "", 0);

        // fallback calls should revert if account is locked
        vm.prank(user1);
        vm.expectRevert(AccountLocked.selector);
        (bool success, bytes memory result) = accountAddress.call(abi.encodeWithSignature("customFunction()"));

        // silence unused variable compiler warnings
        success;
        result;

        // setOverrides calls should revert if account is locked
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = IERC6551Executable.execute.selector;
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
        {
            bytes32 hash = keccak256("This is a signed message");
            (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(2, hash);
            bytes memory signature1 = abi.encodePacked(r1, s1, v1);
            bytes4 returnValue = account.isValidSignature(hash, signature1);
            assertEq(returnValue, 0);
        }

        // warp to timestamp after account is unlocked
        vm.warp(unlockTimestamp + 1 days);

        // transaction succeed now that account lock has expired
        vm.prank(user1);
        account.execute(payable(user1), 1 ether, "", 0);
        assertEq(user1.balance, 1 ether);

        // signing should now that account lock has expired
        bytes32 hashAfterUnlock = keccak256("This is a signed message");
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(1, hashAfterUnlock);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);
        bytes4 returnValue1 = account.isValidSignature(hashAfterUnlock, signature2);
        assertEq(returnValue1, IERC1271.isValidSignature.selector);
    }

    function testCustomOverridesFallback() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // calls succeed with noop if override is undefined
        (bool success, bytes memory result) = accountAddress.call(abi.encodeWithSignature("customFunction()"));
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

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

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
        assertEq(AccountV3(payable(accountAddress)).supportsInterface(type(IERC1155Receiver).interfaceId), true);
    }

    function testCustomPermissions() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

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

    // function testCrossChainCalls() public {
    //     uint256 tokenId = 1;
    //     address user1 = vm.addr(1);
    //     address crossChainExecutor = vm.addr(2);

    //     uint256 chainId = block.chainid + 1;

    //     tokenCollection.mint(user1, tokenId);
    //     assertEq(tokenCollection.ownerOf(tokenId), user1);

    //     address accountAddress = registry.createAccount(
    //         address(implementation), chainId, address(tokenCollection), tokenId, 0, abi.encodeWithSignature("initialize()")
    //     );

    //     vm.deal(accountAddress, 1 ether);

    //     AccountV3 account = AccountV3(payable(accountAddress));

    //     assertEq(account.isAuthorized(crossChainExecutor), false);

    //     guardian.setTrustedExecutor(crossChainExecutor, true);

    //     assertEq(account.isAuthorized(crossChainExecutor), true);

    //     vm.prank(crossChainExecutor);
    //     account.execute(user1, 0.1 ether, "", 0);

    //     assertEq(user1.balance, 0.1 ether);

    //     address notCrossChainExecutor = vm.addr(3);
    //     vm.prank(notCrossChainExecutor);
    //     vm.expectRevert(NotAuthorized.selector);
    //     AccountV3(payable(account)).execute(user1, 0.1 ether, "", 0);

    //     assertEq(user1.balance, 0.1 ether);

    //     address nativeAccountAddress = registry.createAccount(
    //         address(implementation), block.chainid, address(tokenCollection), tokenId, 0, abi.encodeWithSignature("initialize()")
    //     );

    //     vm.prank(crossChainExecutor);
    //     vm.expectRevert(NotAuthorized.selector);
    //     AccountV3(payable(nativeAccountAddress)).execute(user1, 0.1 ether, "", 0);

    //     assertEq(user1.balance, 0.1 ether);
    // }

    function testExecuteCallRevert() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        MockReverter mockReverter = new MockReverter();

        vm.prank(user1);
        vm.expectRevert(MockReverter.MockError.selector);
        account.execute(payable(address(mockReverter)), 0, abi.encodeWithSignature("fail()"), 0);
    }

    function testExecuteCreate() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        AccountV3 account = AccountV3(payable(accountAddress));

        uint256 state = account.state();

        // should succeed when called by owner
        vm.prank(user1);
        bytes memory result = account.execute(address(0), 0, type(MockERC721).creationCode, 2);

        address deployedContract = address(uint160(uint256(bytes32(result)) >> 96));

        // batch execution should change state
        assertTrue(state != account.state());

        assertTrue(deployedContract.code.length > 0);

        // should fail when called by non-owner
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(address(0), 0, type(MockERC721).creationCode, 2);
    }

    function testExecuteCreate2() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        AccountV3 account = AccountV3(payable(accountAddress));

        address computedContract =
            Create2.computeAddress(keccak256("salt"), keccak256(type(MockERC721).creationCode), accountAddress);
        bytes memory payload = abi.encodePacked(keccak256("salt"), type(MockERC721).creationCode);

        uint256 state = account.state();

        // should succeed when called by owner
        vm.prank(user1);
        bytes memory result = account.execute(address(0), 0, payload, 3);

        address deployedContract = address(uint160(uint256(bytes32(result)) >> 96));

        // batch execution should change state
        assertTrue(state != account.state());

        assertEq(computedContract, deployedContract);
        assertTrue(deployedContract.code.length > 0);

        // should fail when called by non-owner
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(address(0), 0, payload, 2);
    }

    function testExecuteBatch() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        Executor.Operation[] memory operations = new Executor.Operation[](3);
        operations[0] = Executor.Operation(vm.addr(2), 0.1 ether, "", 0);
        operations[1] = Executor.Operation(vm.addr(3), 0.1 ether, "", 0);
        operations[2] = Executor.Operation(vm.addr(4), 0.1 ether, "", 0);

        uint256 state = account.state();

        // should succeed when called by owner
        vm.prank(user1);
        account.executeBatch(operations);

        // batch execution should change state
        assertTrue(state != account.state());

        assertEq(vm.addr(2).balance, 0.1 ether);
        assertEq(vm.addr(3).balance, 0.1 ether);
        assertEq(vm.addr(4).balance, 0.1 ether);

        // should fail when called by non-owner
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.executeBatch(operations);
    }

    function testExecuteNested() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        tokenCollection.mint(accountAddress, 2);

        address accountAddress2 =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), 2, 0, "");

        tokenCollection.mint(accountAddress2, 3);

        address accountAddress3 =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), 3, 0, "");

        vm.deal(accountAddress3, 1 ether);

        AccountV3 nestedAccount = AccountV3(payable(accountAddress3));

        Executor.ERC6551AccountInfo[] memory proof = new Executor.ERC6551AccountInfo[](2);
        proof[0] = Executor.ERC6551AccountInfo(address(tokenCollection), 1, 0);
        proof[1] = Executor.ERC6551AccountInfo(address(tokenCollection), 2, 0);

        uint256 state = nestedAccount.state();

        // should succeed when called by owner
        vm.prank(user1);
        nestedAccount.executeNested(vm.addr(2), 0.1 ether, "", 0, proof);

        // nested execution should change state
        assertTrue(state != nestedAccount.state());

        assertEq(vm.addr(2).balance, 0.1 ether);

        // should fail when called by non-owner
        vm.prank(user2);
        vm.expectRevert(InvalidAccountProof.selector);
        nestedAccount.executeNested(vm.addr(2), 0.1 ether, "", 0, proof);
    }

    function testExecuteForwarder() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), tokenId, 0, "");

        tokenCollection.mint(user1, 2);

        address accountAddress2 =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), 2, 0, "");

        tokenCollection.mint(user1, 3);

        address accountAddress3 =
            registry.createAccount(address(implementation), block.chainid, address(tokenCollection), 3, 0, "");

        vm.deal(accountAddress, 1 ether);
        vm.deal(accountAddress2, 1 ether);
        vm.deal(accountAddress3, 1 ether);

        MulticallForwarder.Call[] memory calls = new MulticallForwarder.Call[](3);
        calls[0] = MulticallForwarder.Call(
            accountAddress,
            abi.encodeWithSignature("execute(address,uint256,bytes,uint256)", vm.addr(2), 0.1 ether, "", 0)
        );
        calls[1] = MulticallForwarder.Call(
            accountAddress2,
            abi.encodeWithSignature("execute(address,uint256,bytes,uint256)", vm.addr(2), 0.1 ether, "", 0)
        );
        calls[2] = MulticallForwarder.Call(
            accountAddress3,
            abi.encodeWithSignature("execute(address,uint256,bytes,uint256)", vm.addr(2), 0.1 ether, "", 0)
        );

        vm.prank(user1);
        forwarder.forward(calls);

        assertEq(user2.balance, 0.3 ether);

        // should fail when called by non-owner
        vm.prank(user2);
        MulticallForwarder.Result[] memory results = forwarder.forward(calls);

        // balance should not have changed
        assertEq(user2.balance, 0.3 ether);

        for (uint256 i = 0; i < results.length; i++) {
            assertFalse(results[i].success);
            assertEq(bytes4(results[i].returnData), NotAuthorized.selector);
        }
    }

    function testAccountOwnerIsNullIfContextNotSet() public {
        address accountClone = Clones.clone(address(implementation));

        assertEq(AccountV3(payable(accountClone)).owner(), address(0));
    }

    function testEIP165Support() public {
        uint256 tokenId = 1;

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0,
            abi.encodeWithSignature("initialize()")
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        assertEq(account.supportsInterface(0x6faff5f1), true); // IERC6551Account
        assertEq(account.supportsInterface(0x74420f4c), true); // IERC6551Executable
        assertEq(account.supportsInterface(type(IERC1155Receiver).interfaceId), true);
        assertEq(account.supportsInterface(type(IERC165).interfaceId), true);
    }

    function testAccountUpgrade() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(proxy), block.chainid, address(tokenCollection), tokenId, 0, abi.encodeWithSignature("initialize()")
        );

        AccountV3Upgradable account = AccountV3Upgradable(payable(accountAddress));

        MockAccountUpgradable upgradedImplementation = new MockAccountUpgradable(
            address(0),
            address(0),
            address(0)
        );

        // TODO: account guardian test

        // vm.expectRevert(UntrustedImplementation.selector);
        // vm.prank(user1);
        // account.upgradeTo(address(upgradedImplementation));

        // guardian.setTrustedImplementation(address(upgradedImplementation), true);

        vm.prank(user1);
        account.upgradeTo(address(upgradedImplementation));
        uint256 returnValue = MockAccountUpgradable(payable(accountAddress)).customFunction();

        assertEq(returnValue, 12345);
    }

    function testProxyZeroAddressInit() public {
        vm.expectRevert(InvalidImplementation.selector);
        new AccountProxy(address(0));
    }
}
