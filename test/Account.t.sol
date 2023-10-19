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

import "multicall-authenticated/Multicall3.sol";

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
    Multicall3 forwarder;
    AccountV3 implementation;
    AccountV3Upgradable upgradableImplementation;
    AccountProxy proxy;
    ERC6551Registry public registry;
    AccountGuardian public guardian;

    MockERC721 public tokenCollection;

    function setUp() public {
        registry = new ERC6551Registry();

        forwarder = new Multicall3();
        guardian = new AccountGuardian(address(this));
        implementation = new AccountV3(
            address(1), address(forwarder), address(registry), address(guardian)
        );
        upgradableImplementation = new AccountV3Upgradable(
            address(1), address(forwarder), address(registry), address(guardian)
        );
        proxy = new AccountProxy(address(guardian), address(upgradableImplementation));

        tokenCollection = new MockERC721();

        // mint tokenId 1 during setup for accurate cold call gas measurement
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        tokenCollection.mint(user1, tokenId);
    }

    function testNonOwnerCallsFail() public {
        uint256 tokenId = 1;
        address user2 = vm.addr(2);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(payable(user2), 0.1 ether, "", LibExecutor.OP_CALL);

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(payable(user2), 0.1 ether, "", LibExecutor.OP_CALL);
    }

    function testAccountOwnershipTransfer() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        // should succeed with original owner
        vm.prank(user1);
        account.execute(payable(user1), 0.1 ether, "", LibExecutor.OP_CALL);

        // should fail if user2 tries to use account
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(payable(user2), 0.1 ether, "", LibExecutor.OP_CALL);

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, user2, tokenId);

        // should succeed now that user2 is owner
        vm.prank(user2);
        account.execute(payable(user2), 0.1 ether, "", LibExecutor.OP_CALL);

        assertEq(user2.balance, 0.1 ether);
    }

    function testSignatureVerification() public {
        uint256 tokenId = 1;

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 account = AccountV3(payable(accountAddress));

        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, hash);

        // ECDSA signature
        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes4 returnValue = account.isValidSignature(hash, signature1);
        assertEq(returnValue, IERC1271.isValidSignature.selector);

        MockSigner mockSigner = new MockSigner();

        address[] memory callers = new address[](1);
        callers[0] = address(mockSigner);
        bool[] memory _permissions = new bool[](1);
        _permissions[0] = true;

        vm.prank(vm.addr(1));
        account.setPermissions(callers, _permissions);

        // ERC-1271 signature
        bytes memory contractSignature = abi.encodePacked(
            uint256(uint160(address(mockSigner))), uint256(65), uint8(0), signature1
        );
        returnValue = account.isValidSignature(hash, contractSignature);
        assertEq(returnValue, IERC1271.isValidSignature.selector);

        // ERC-1271 signature invalid
        _permissions[0] = false;
        vm.prank(vm.addr(1));
        account.setPermissions(callers, _permissions);
        returnValue = account.isValidSignature(hash, contractSignature);
        assertEq(returnValue, bytes4(0));

        // Recursive account signature
        bytes memory recursiveSignature =
            abi.encodePacked(uint256(uint160(address(account))), uint256(65), uint8(0), signature1);
        returnValue = account.isValidSignature(hash, recursiveSignature);
        assertEq(returnValue, IERC1271.isValidSignature.selector);
    }

    function testSignatureVerificationFailsInvalidSigner() public {
        uint256 tokenId = 1;

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

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

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

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
        account.execute(payable(user1), 1 ether, "", LibExecutor.OP_CALL);

        // fallback calls should revert if account is locked
        vm.prank(user1);
        (bool success, bytes memory result) =
            accountAddress.call(abi.encodeWithSignature("customFunction()"));

        console.log(success);
        console.logBytes(result);

        // setOverrides calls should revert if account is locked
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = IERC721Receiver.onERC721Received.selector;
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

    function testExecuteCallRevert() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        MockReverter mockReverter = new MockReverter();

        vm.prank(user1);
        vm.expectRevert(MockReverter.MockError.selector);
        account.execute(payable(address(mockReverter)), 0, abi.encodeWithSignature("fail()"), 0);
    }

    function testExecuteInvalidOperation() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        vm.prank(user1);
        vm.expectRevert(InvalidOperation.selector);
        account.execute(vm.addr(2), 0.1 ether, "", type(uint8).max);
    }

    function testExecuteCreate() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

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

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountV3 account = AccountV3(payable(accountAddress));

        address computedContract = Create2.computeAddress(
            keccak256("salt"), keccak256(type(MockERC721).creationCode), accountAddress
        );
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

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        BatchExecutor.Operation[] memory operations = new BatchExecutor.Operation[](3);
        operations[0] = BatchExecutor.Operation(vm.addr(2), 0.1 ether, "", 0);
        operations[1] = BatchExecutor.Operation(vm.addr(3), 0.1 ether, "", 0);
        operations[2] = BatchExecutor.Operation(vm.addr(4), 0.1 ether, "", 0);

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

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(accountAddress, 2);

        // Account for tokenId 2 not deployed
        address accountAddress2 =
            registry.account(address(implementation), 0, block.chainid, address(tokenCollection), 2);

        tokenCollection.mint(accountAddress2, 3);

        address accountAddress3 = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), 3
        );

        vm.deal(accountAddress3, 1 ether);

        console.log("accounts");
        console.log(vm.addr(1), accountAddress, accountAddress2, accountAddress3);

        AccountV3 nestedAccount = AccountV3(payable(accountAddress3));

        NestedAccountExecutor.ERC6551AccountInfo[] memory proof =
            new NestedAccountExecutor.ERC6551AccountInfo[](2);
        proof[0] = NestedAccountExecutor.ERC6551AccountInfo(0, address(tokenCollection), 1);
        proof[1] = NestedAccountExecutor.ERC6551AccountInfo(0, address(tokenCollection), 2);

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

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        tokenCollection.mint(user1, 2);

        address accountAddress2 = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), 2
        );

        tokenCollection.mint(user1, 3);

        address accountAddress3 = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), 3
        );

        vm.deal(accountAddress, 1 ether);
        vm.deal(accountAddress2, 1 ether);
        vm.deal(accountAddress3, 1 ether);

        Multicall3.Call3[] memory calls = new Multicall3.Call3[](3);
        calls[0] = Multicall3.Call3(
            accountAddress,
            false,
            abi.encodeWithSignature(
                "execute(address,uint256,bytes,uint8)",
                vm.addr(2),
                0.1 ether,
                "",
                LibExecutor.OP_CALL
            )
        );
        calls[1] = Multicall3.Call3(
            accountAddress2,
            false,
            abi.encodeWithSignature(
                "execute(address,uint256,bytes,uint8)",
                vm.addr(2),
                0.1 ether,
                "",
                LibExecutor.OP_CALL
            )
        );
        calls[2] = Multicall3.Call3(
            accountAddress3,
            false,
            abi.encodeWithSignature(
                "execute(address,uint256,bytes,uint8)",
                vm.addr(2),
                0.1 ether,
                "",
                LibExecutor.OP_CALL
            )
        );

        vm.prank(user1);
        Multicall3.Result[] memory results = forwarder.aggregate3(calls);
        for (uint256 i = 0; i < results.length; i++) {
            assertTrue(results[i].success);
            assertEq(results[i].returnData, abi.encode(new bytes(0)));
        }

        assertEq(user2.balance, 0.3 ether);

        // should fail when called by non-owner
        vm.prank(user2);
        vm.expectRevert("Multicall3: call failed");
        results = forwarder.aggregate3(calls);

        // balance should not have changed
        assertEq(user2.balance, 0.3 ether);

        for (uint256 i = 0; i < results.length; i++) {
            assertFalse(results[i].success);
            assertEq(bytes4(results[i].returnData), NotAuthorized.selector);
        }
    }

    function testExecuteSandbox() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        vm.expectRevert(NotAuthorized.selector);
        account.extcall(vm.addr(2), 0.1 ether, "");

        vm.expectRevert(NotAuthorized.selector);
        account.extcreate(0, type(MockERC721).creationCode);

        vm.expectRevert(NotAuthorized.selector);
        account.extcreate2(0, keccak256("salt"), type(MockERC721).creationCode);

        MockSandboxExecutor mockSandboxExecutor = new MockSandboxExecutor();

        vm.prank(user1);
        vm.expectRevert(MockReverter.MockError.selector);
        account.execute(
            address(mockSandboxExecutor),
            0,
            abi.encodeWithSignature("fail()"),
            LibExecutor.OP_DELEGATECALL
        );

        vm.prank(user1);
        bytes memory result = account.execute(
            address(mockSandboxExecutor),
            0,
            abi.encodeWithSignature("customFunction()"),
            LibExecutor.OP_DELEGATECALL
        );

        assertEq(uint256(bytes32(result)), 12345);

        vm.prank(user1);
        result = account.execute(
            address(mockSandboxExecutor),
            0,
            abi.encodeWithSignature("sentEther(address,uint256)", vm.addr(2), 0.1 ether),
            LibExecutor.OP_DELEGATECALL
        );

        assertEq(accountAddress.balance, 0.9 ether);
        assertEq(vm.addr(2).balance, 0.1 ether);

        vm.prank(user1);
        result = account.execute(
            address(mockSandboxExecutor),
            0,
            abi.encodeWithSignature("createNFT()"),
            LibExecutor.OP_DELEGATECALL
        );
        address deployedNFT = address(uint160(uint256(bytes32(result))));

        assertTrue(deployedNFT.code.length > 0);

        vm.prank(user1);
        result = account.execute(
            address(mockSandboxExecutor),
            0,
            abi.encodeWithSignature("createNFTDeterministic()"),
            LibExecutor.OP_DELEGATECALL
        );
        deployedNFT = address(uint160(uint256(bytes32(result))));

        assertTrue(deployedNFT.code.length > 0);

        vm.prank(user1);
        result = account.execute(
            address(mockSandboxExecutor),
            0,
            abi.encodeWithSignature("getSlot0()"),
            LibExecutor.OP_DELEGATECALL
        );
        assertEq(uint256(bytes32(result)), 0);
    }

    function testAccountOwnerIsNullIfContextNotSet() public {
        address accountClone = Clones.clone(address(implementation));

        assertEq(AccountV3(payable(accountClone)).owner(), address(0));
    }

    function testEIP165Support() public {
        uint256 tokenId = 1;

        address accountAddress = registry.createAccount(
            address(implementation), 0, block.chainid, address(tokenCollection), tokenId
        );

        vm.deal(accountAddress, 1 ether);

        AccountV3 account = AccountV3(payable(accountAddress));

        assertEq(account.supportsInterface(0x6faff5f1), true); // IERC6551Account
        assertEq(account.supportsInterface(0x51945447), true); // IERC6551Executable
        assertEq(account.supportsInterface(type(IERC1155Receiver).interfaceId), true);
        assertEq(account.supportsInterface(type(IERC165).interfaceId), true);
    }

    function testAccountUpgrade() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);

        address accountAddress = registry.createAccount(
            address(proxy), 0, block.chainid, address(tokenCollection), tokenId
        );

        AccountProxy(payable(accountAddress)).initialize(address(upgradableImplementation));
        AccountV3Upgradable account = AccountV3Upgradable(payable(accountAddress));

        MockAccountUpgradable upgradedImplementation = new MockAccountUpgradable(
            address(1),
            address(1),
            address(1),
            address(1)
        );

        vm.expectRevert(InvalidImplementation.selector);
        vm.prank(user1);
        account.upgradeTo(address(upgradedImplementation));

        guardian.setTrustedImplementation(address(upgradedImplementation), true);

        vm.prank(user1);
        account.upgradeTo(address(upgradedImplementation));
        uint256 returnValue = MockAccountUpgradable(payable(accountAddress)).customFunction();

        assertEq(returnValue, 12345);
    }

    function testProxyZeroAddressInit() public {
        vm.expectRevert(InvalidImplementation.selector);
        new AccountProxy(address(1), address(0));
        vm.expectRevert(InvalidImplementation.selector);
        new AccountProxy(address(0), address(1));
    }
}
