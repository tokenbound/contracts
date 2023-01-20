// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import "../src/Vault.sol";
import "../src/VaultRegistry.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockERC1155.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockExecutor.sol";
import "./mocks/MockReverter.sol";

contract VaultTest is Test {
    MockERC721 public dummyERC721;
    MockERC1155 public dummyERC1155;
    MockERC20 public dummyERC20;

    VaultRegistry public vaultRegistry;

    MockERC721 public tokenCollection;

    function setUp() public {
        dummyERC721 = new MockERC721();
        dummyERC1155 = new MockERC1155();
        dummyERC20 = new MockERC20();

        vaultRegistry = new VaultRegistry();

        tokenCollection = new MockERC721();
    }

    function testTransferETHPreDeploy() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        // get address that vault will be deployed to (before token is minted)
        address vaultAddress = vaultRegistry.vaultAddress(
            address(tokenCollection),
            tokenId
        );

        // mint token for vault to user1
        tokenCollection.mint(user1, tokenId);

        assertEq(tokenCollection.ownerOf(tokenId), user1);

        // send ETH from user1 to vault (prior to vault deployment)
        vm.prank(user1);
        (bool sent, ) = vaultAddress.call{value: 0.2 ether}("");
        assertTrue(sent);

        assertEq(vaultAddress.balance, 0.2 ether);

        // deploy vault contract (from a different wallet)
        address createdVaultInstance = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        assertEq(vaultAddress, createdVaultInstance);

        Vault vault = Vault(payable(vaultAddress));

        // user1 executes transaction to send ETH from vault
        vm.prank(user1);
        vault.executeCall(payable(user1), 0.1 ether, "");

        // success!
        assertEq(vaultAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function testTransferETHPostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);

        assertEq(tokenCollection.ownerOf(tokenId), user1);

        vm.prank(user1);
        (bool sent, ) = vaultAddress.call{value: 0.2 ether}("");
        assertTrue(sent);

        assertEq(vaultAddress.balance, 0.2 ether);

        Vault vault = Vault(payable(vaultAddress));

        vm.prank(user1);
        vault.executeCall(payable(user1), 0.1 ether, "");

        assertEq(vaultAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function testTransferERC20PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedVaultInstance = vaultRegistry.vaultAddress(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(computedVaultInstance, 1 ether);

        assertEq(dummyERC20.balanceOf(computedVaultInstance), 1 ether);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(payable(vaultAddress));

        bytes memory erc20TransferCall = abi.encodeWithSignature(
            "transfer(address,uint256)",
            user1,
            1 ether
        );
        vm.prank(user1);
        vault.executeCall(payable(address(dummyERC20)), 0, erc20TransferCall);

        assertEq(dummyERC20.balanceOf(vaultAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }

    function testTransferERC20PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(vaultAddress, 1 ether);

        assertEq(dummyERC20.balanceOf(vaultAddress), 1 ether);

        Vault vault = Vault(payable(vaultAddress));

        bytes memory erc20TransferCall = abi.encodeWithSignature(
            "transfer(address,uint256)",
            user1,
            1 ether
        );
        vm.prank(user1);
        vault.executeCall(payable(address(dummyERC20)), 0, erc20TransferCall);

        assertEq(dummyERC20.balanceOf(vaultAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }

    function testTransferERC1155PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedVaultInstance = vaultRegistry.vaultAddress(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(computedVaultInstance, 1, 10);

        assertEq(dummyERC1155.balanceOf(computedVaultInstance, 1), 10);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(payable(vaultAddress));

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            vaultAddress,
            user1,
            1,
            10,
            ""
        );
        vm.prank(user1);
        vault.executeCall(
            payable(address(dummyERC1155)),
            0,
            erc1155TransferCall
        );

        assertEq(dummyERC1155.balanceOf(vaultAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }

    function testTransferERC1155PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(vaultAddress, 1, 10);

        assertEq(dummyERC1155.balanceOf(vaultAddress, 1), 10);

        Vault vault = Vault(payable(vaultAddress));

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            vaultAddress,
            user1,
            1,
            10,
            ""
        );
        vm.prank(user1);
        vault.executeCall(
            payable(address(dummyERC1155)),
            0,
            erc1155TransferCall
        );

        assertEq(dummyERC1155.balanceOf(vaultAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }

    function testTransferERC721PreDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address computedVaultInstance = vaultRegistry.vaultAddress(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC721.mint(computedVaultInstance, 1);

        assertEq(dummyERC721.balanceOf(computedVaultInstance), 1);
        assertEq(dummyERC721.ownerOf(1), computedVaultInstance);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(payable(vaultAddress));

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(vaultAddress),
            user1,
            1
        );
        vm.prank(user1);
        vault.executeCall(payable(address(dummyERC721)), 0, erc721TransferCall);

        assertEq(dummyERC721.balanceOf(address(vaultAddress)), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }

    function testTransferERC721PostDeploy(uint256 tokenId) public {
        address user1 = vm.addr(1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC721.mint(vaultAddress, 1);

        assertEq(dummyERC721.balanceOf(vaultAddress), 1);
        assertEq(dummyERC721.ownerOf(1), vaultAddress);

        Vault vault = Vault(payable(vaultAddress));

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            vaultAddress,
            user1,
            1
        );
        vm.prank(user1);
        vault.executeCall(payable(address(dummyERC721)), 0, erc721TransferCall);

        assertEq(dummyERC721.balanceOf(vaultAddress), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }

    function testNonOwnerCallsFail(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        vm.deal(vaultAddress, 1 ether);

        Vault vault = Vault(payable(vaultAddress));

        // should fail if user2 tries to use vault
        vm.prank(user2);
        vm.expectRevert(Vault.NotAuthorized.selector);
        vault.executeCall(payable(user2), 0.1 ether, "");

        // should fail if user2 tries to set executor
        vm.prank(user2);
        vm.expectRevert(Vault.NotAuthorized.selector);
        vault.setExecutor(vm.addr(1337));

        // should fail if user2 tries to lock vault
        vm.prank(user2);
        vm.expectRevert(Vault.NotAuthorized.selector);
        vault.lock(364 days);
    }

    function testVaultOwnershipTransfer(uint256 tokenId) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        vm.deal(vaultAddress, 1 ether);

        Vault vault = Vault(payable(vaultAddress));

        // should fail if user2 tries to use vault
        vm.prank(user2);
        vm.expectRevert(Vault.NotAuthorized.selector);
        vault.executeCall(payable(user2), 0.1 ether, "");

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, user2, tokenId);

        // should succeed now that user2 is owner
        vm.prank(user2);
        vault.executeCall(payable(user2), 0.1 ether, "");

        assertEq(user2.balance, 0.1 ether);
    }

    function testMessageSigningAndVerificationForAuthorizedUser(uint256 tokenId)
        public
    {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(payable(vaultAddress));

        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, hash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        bytes4 returnValue1 = vault.isValidSignature(hash, signature1);

        assertEq(returnValue1, IERC1271.isValidSignature.selector);
    }

    function testMessageSigningAndVerificationForUnauthorizedUser(
        uint256 tokenId
    ) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(payable(vaultAddress));

        bytes32 hash = keccak256("This is a signed message");

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(2, hash);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes4 returnValue2 = vault.isValidSignature(hash, signature2);

        assertEq(returnValue2, 0);
    }

    function testVaultLocksAndUnlocks(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        vm.deal(vaultAddress, 1 ether);

        Vault vault = Vault(payable(vaultAddress));

        // cannot be locked for more than 365 days
        vm.prank(user1);
        vm.expectRevert(Vault.ExceedsMaxLockTime.selector);
        vault.lock(366 days);

        // lock vault for 10 days
        uint256 unlockTimestamp = block.timestamp + 10 days;
        vm.prank(user1);
        vault.lock(unlockTimestamp);

        assertEq(vault.isLocked(), true);

        // transaction should revert if vault is locked
        vm.prank(user1);
        vm.expectRevert(Vault.VaultLocked.selector);
        vault.executeCall(payable(user1), 1 ether, "");

        // fallback calls should revert if vault is locked
        vm.prank(user1);
        vm.expectRevert(Vault.VaultLocked.selector);
        (bool success, bytes memory result) = vaultAddress.call(
            abi.encodeWithSignature("customFunction()")
        );

        // silence unused variable compiler warnings
        success;
        result;

        // setExecutor calls should revert if vault is locked
        vm.prank(user1);
        vm.expectRevert(Vault.VaultLocked.selector);
        vault.setExecutor(vm.addr(1337));

        // lock calls should revert if vault is locked
        vm.prank(user1);
        vm.expectRevert(Vault.VaultLocked.selector);
        vault.lock(0);

        // signing should fail if vault is locked
        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(2, hash);
        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes4 returnValue = vault.isValidSignature(hash, signature1);
        assertEq(returnValue, 0);

        // warp to timestamp after vault is unlocked
        vm.warp(unlockTimestamp + 1 days);

        // transaction succeed now that vault lock has expired
        vm.prank(user1);
        vault.executeCall(payable(user1), 1 ether, "");
        assertEq(user1.balance, 1 ether);

        // signing should now that vault lock has expired
        bytes32 hashAfterUnlock = keccak256("This is a signed message");
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(1, hashAfterUnlock);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);
        bytes4 returnValue1 = vault.isValidSignature(
            hashAfterUnlock,
            signature2
        );
        assertEq(returnValue1, IERC1271.isValidSignature.selector);
    }

    function testCustomExecutionModule(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        vm.deal(vaultAddress, 1 ether);

        Vault vault = Vault(payable(vaultAddress));

        MockExecutor mockExecutor = new MockExecutor();

        // calls succeed with noop if executor is undefined
        (bool success, bytes memory result) = vaultAddress.call(
            abi.encodeWithSignature("customFunction()")
        );
        assertEq(success, true);
        assertEq(result, "");

        // calls succeed with noop if executor is EOA
        vm.prank(user1);
        vault.setExecutor(vm.addr(1337));
        (bool success1, bytes memory result1) = vaultAddress.call(
            abi.encodeWithSignature("customFunction()")
        );
        assertEq(success1, true);
        assertEq(result1, "");

        assertEq(vault.isAuthorized(user1), true);
        assertEq(vault.isAuthorized(address(mockExecutor)), false);

        vm.prank(user1);
        vault.setExecutor(address(mockExecutor));

        assertEq(vault.isAuthorized(user1), true);
        assertEq(vault.isAuthorized(address(mockExecutor)), true);

        assertEq(
            vault.isValidSignature(bytes32(0), ""),
            IERC1271.isValidSignature.selector
        );

        // execution module handles fallback calls
        assertEq(MockExecutor(vaultAddress).customFunction(), 12345);

        // execution bubbles up errors on revert
        vm.expectRevert(MockReverter.MockError.selector);
        MockExecutor(vaultAddress).fail();
    }

    function testExecuteCallRevert(uint256 tokenId) public {
        address user1 = vm.addr(1);

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        vm.deal(vaultAddress, 1 ether);

        Vault vault = Vault(payable(vaultAddress));

        MockReverter mockReverter = new MockReverter();

        vm.prank(user1);
        vm.expectRevert(MockReverter.MockError.selector);
        vault.executeCall(
            payable(address(mockReverter)),
            0,
            abi.encodeWithSignature("fail()")
        );
    }

    function testVaultOwnerIsNullIfContextNotSet() public {
        address vaultClone = Clones.clone(vaultRegistry.vaultImplementation());

        assertEq(Vault(payable(vaultClone)).owner(), address(0));
    }
}
