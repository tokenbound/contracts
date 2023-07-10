// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "account-abstraction/core/EntryPoint.sol";

import "erc6551/ERC6551Registry.sol";
import "erc6551/interfaces/IERC6551Account.sol";

import "../src/Account.sol";
import "../src/AccountGuardian.sol";

import "./mocks/MockERC721.sol";

contract AccountERC4337Test is Test {
    using ECDSA for bytes32;

    Account implementation;
    AccountGuardian public guardian;
    ERC6551Registry public registry;
    IEntryPoint public entryPoint;

    MockERC721 public tokenCollection;

    function setUp() public {
        entryPoint = new EntryPoint();
        guardian = new AccountGuardian();
        implementation = new Account(address(guardian), address(entryPoint));
        registry = new ERC6551Registry();

        tokenCollection = new MockERC721();
    }

    function testReturnsEntryPoint() public {
        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            1,
            0,
            ""
        );

        assertEq(
            address(Account(payable(accountAddress)).entryPoint()),
            address(entryPoint)
        );
    }

    function testNonceIncrementsOnDirectCall(uint256 tokenId) public {
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

        vm.deal(accountAddress, 1 ether);

        Account account = Account(payable(accountAddress));

        uint256 nonce = account.nonce();
        assertEq(nonce, 0);

        // user1 executes transaction to send ETH from account
        vm.prank(user1);
        account.executeCall(payable(user1), 0.1 ether, "");

        assertEq(account.nonce(), nonce + 1);
        assertEq(account.nonce(), entryPoint.getNonce(accountAddress, 0));

        // success!
        assertEq(accountAddress.balance, 0.9 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function test4337CallCreateAccount() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address accountAddress = registry.account(
            address(implementation),
            block.chainid,
            address(tokenCollection),
            tokenId,
            0
        );

        bytes memory initCode = abi.encodePacked(
            address(registry),
            abi.encodeWithSignature(
                "createAccount(address,uint256,address,uint256,uint256,bytes)",
                address(implementation),
                block.chainid,
                address(tokenCollection),
                tokenId,
                0,
                ""
            )
        );

        bytes memory callData = abi.encodeWithSignature(
            "executeCall(address,uint256,bytes)",
            user2,
            0.1 ether,
            ""
        );

        UserOperation memory op = UserOperation({
            sender: accountAddress,
            nonce: 0,
            initCode: initCode,
            callData: callData,
            callGasLimit: 1000000,
            verificationGasLimit: 1000000,
            preVerificationGas: 1000000,
            maxFeePerGas: block.basefee + 10,
            maxPriorityFeePerGas: 10,
            paymasterAndData: "",
            signature: ""
        });

        bytes32 opHash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            opHash.toEthSignedMessageHash()
        );

        bytes memory signature = abi.encodePacked(r, s, v);
        op.signature = signature;

        vm.deal(accountAddress, 1 ether);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;

        assertEq(entryPoint.getNonce(accountAddress, 0), 0);
        entryPoint.handleOps(ops, payable(user1));
        assertEq(entryPoint.getNonce(accountAddress, 0), 1);

        assertEq(user2.balance, 0.1 ether);
        assertTrue(accountAddress.balance < 0.9 ether);
    }

    function test4337CallExistingAccount() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

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

        bytes memory callData = abi.encodeWithSignature(
            "executeCall(address,uint256,bytes)",
            user2,
            0.1 ether,
            ""
        );

        UserOperation memory op = UserOperation({
            sender: accountAddress,
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 1000000,
            verificationGasLimit: 1000000,
            preVerificationGas: 1000000,
            maxFeePerGas: block.basefee + 10,
            maxPriorityFeePerGas: 10,
            paymasterAndData: "",
            signature: ""
        });

        bytes32 opHash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            opHash.toEthSignedMessageHash()
        );

        bytes memory signature = abi.encodePacked(r, s, v);
        op.signature = signature;

        vm.deal(accountAddress, 1 ether);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;

        assertEq(entryPoint.getNonce(accountAddress, 0), 0);
        entryPoint.handleOps(ops, payable(user1));
        assertEq(entryPoint.getNonce(accountAddress, 0), 1);

        assertEq(user2.balance, 0.1 ether);
        assertTrue(accountAddress.balance < 0.9 ether);
    }

    function test4337CallRevertsInvalidSignature() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

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

        bytes memory callData = abi.encodeWithSignature(
            "executeCall(address,uint256,bytes)",
            user2,
            0.1 ether,
            ""
        );

        UserOperation memory op = UserOperation({
            sender: accountAddress,
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 1000000,
            verificationGasLimit: 1000000,
            preVerificationGas: 1000000,
            maxFeePerGas: block.basefee + 10,
            maxPriorityFeePerGas: 10,
            paymasterAndData: "",
            signature: ""
        });

        bytes32 opHash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            opHash.toEthSignedMessageHash()
        );

        // invalidate signature
        bytes memory signature = abi.encodePacked(r, s, v + 1);
        op.signature = signature;

        vm.deal(accountAddress, 1 ether);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;

        vm.expectRevert();
        entryPoint.handleOps(ops, payable(user1));

        assertEq(accountAddress.balance, 1 ether);
    }
}
