// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/beacon/UpgradeableBeacon.sol";

import "../src/Vault.sol";
import "../src/VaultRegistry.sol";

contract VaultCollectionTest is Test {
    DummyERC721 public dummyERC721;
    DummyERC1155 public dummyERC1155;
    DummyERC20 public dummyERC20;

    Vault public vaultImplementation;
    UpgradeableBeacon public vaultBeacon;
    VaultRegistry public vaultRegistry;

    TokenCollection public tokenCollection;

    event Initialized(uint8 version);

    function setUp() public {
        dummyERC721 = new DummyERC721();
        dummyERC1155 = new DummyERC1155();
        dummyERC20 = new DummyERC20();

        vaultImplementation = new Vault();
        vaultBeacon = new UpgradeableBeacon(address(vaultImplementation));

        vaultRegistry = new VaultRegistry(address(vaultBeacon));

        tokenCollection = new TokenCollection();
    }

    function testDeployVault() public {
        assertTrue(address(vaultRegistry) != address(0));

        uint16 tokenId = 1;

        address predictedVaultAddress = vaultRegistry.getVault(
            address(tokenCollection),
            tokenId
        );

        // expect vault to be initialized on creation
        vm.expectEmit(
            true,
            false,
            false,
            false,
            address(predictedVaultAddress)
        );
        emit Initialized(1);

        address vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        assertTrue(vaultAddress != address(0));
        assertTrue(vaultAddress == predictedVaultAddress);
    }

    function testTransferETHPreDeploy() public {
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        uint256 tokenId = 1;

        // get address that vault will be deployed to (before token is minted)
        address payable vaultAddress = vaultRegistry.getVault(
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
        address payable createdVaultInstance = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        assertEq(vaultAddress, createdVaultInstance);

        Vault vault = Vault(vaultAddress);

        // user1 executes transaction to send ETH from vault
        vm.prank(user1);
        vault.execTransaction(
            payable(user1),
            0.1 ether,
            "",
            address(tokenCollection),
            tokenId
        );

        // success!
        assertEq(vaultAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function testTransferETHPostDeploy() public {
        address user1 = vm.addr(1);
        vm.deal(user1, 0.2 ether);

        uint256 tokenId = 2;

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);

        assertEq(tokenCollection.ownerOf(tokenId), user1);

        vm.prank(user1);
        (bool sent, ) = vaultAddress.call{value: 0.2 ether}("");
        assertTrue(sent);

        assertEq(vaultAddress.balance, 0.2 ether);

        Vault vault = Vault(vaultAddress);

        vm.prank(user1);
        vault.execTransaction(
            payable(user1),
            0.1 ether,
            "",
            address(tokenCollection),
            tokenId
        );

        assertEq(vaultAddress.balance, 0.1 ether);
        assertEq(user1.balance, 0.1 ether);
    }

    function testTransferERC20PreDeploy() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 3;

        address payable computedVaultInstance = vaultRegistry.getVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(computedVaultInstance, 1 ether);

        assertEq(dummyERC20.balanceOf(computedVaultInstance), 1 ether);

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(vaultAddress);

        bytes memory erc20TransferCall = abi.encodeWithSignature(
            "transfer(address,uint256)",
            user1,
            1 ether
        );
        vm.prank(user1);
        vault.execTransaction(
            payable(address(dummyERC20)),
            0,
            erc20TransferCall,
            address(tokenCollection),
            tokenId
        );

        assertEq(dummyERC20.balanceOf(vaultAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }

    function testTransferERC20PostDeploy() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 4;

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC20.mint(vaultAddress, 1 ether);

        assertEq(dummyERC20.balanceOf(vaultAddress), 1 ether);

        Vault vault = Vault(vaultAddress);

        bytes memory erc20TransferCall = abi.encodeWithSignature(
            "transfer(address,uint256)",
            user1,
            1 ether
        );
        vm.prank(user1);
        vault.execTransaction(
            payable(address(dummyERC20)),
            0,
            erc20TransferCall,
            address(tokenCollection),
            tokenId
        );

        assertEq(dummyERC20.balanceOf(vaultAddress), 0);
        assertEq(dummyERC20.balanceOf(user1), 1 ether);
    }

    function testTransferERC1155PreDeploy() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 5;

        address payable computedVaultInstance = vaultRegistry.getVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(computedVaultInstance, 1, 10);

        assertEq(dummyERC1155.balanceOf(computedVaultInstance, 1), 10);

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(vaultAddress);

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            vaultAddress,
            user1,
            1,
            10,
            ""
        );
        vm.prank(user1);
        vault.execTransaction(
            payable(address(dummyERC1155)),
            0,
            erc1155TransferCall,
            address(tokenCollection),
            tokenId
        );

        assertEq(dummyERC1155.balanceOf(vaultAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }

    function testTransferERC1155PostDeploy() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 6;

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC1155.mint(vaultAddress, 1, 10);

        assertEq(dummyERC1155.balanceOf(vaultAddress, 1), 10);

        Vault vault = Vault(vaultAddress);

        bytes memory erc1155TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            vaultAddress,
            user1,
            1,
            10,
            ""
        );
        vm.prank(user1);
        vault.execTransaction(
            payable(address(dummyERC1155)),
            0,
            erc1155TransferCall,
            address(tokenCollection),
            tokenId
        );

        assertEq(dummyERC1155.balanceOf(vaultAddress, 1), 0);
        assertEq(dummyERC1155.balanceOf(user1, 1), 10);
    }

    function testTransferERC721PreDeploy() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 7;

        address payable computedVaultInstance = vaultRegistry.getVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC721.mint(computedVaultInstance, 1);

        assertEq(dummyERC721.balanceOf(computedVaultInstance), 1);
        assertEq(dummyERC721.ownerOf(1), computedVaultInstance);

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(vaultAddress);

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(vaultAddress),
            user1,
            1
        );
        vm.prank(user1);
        vault.execTransaction(
            payable(address(dummyERC721)),
            0,
            erc721TransferCall,
            address(tokenCollection),
            tokenId
        );

        assertEq(dummyERC721.balanceOf(address(vaultAddress)), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }

    function testTransferERC721PostDeploy() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 8;

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        dummyERC721.mint(vaultAddress, 1);

        assertEq(dummyERC721.balanceOf(vaultAddress), 1);
        assertEq(dummyERC721.ownerOf(1), vaultAddress);

        Vault vault = Vault(vaultAddress);

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            vaultAddress,
            user1,
            1
        );
        vm.prank(user1);
        vault.execTransaction(
            payable(address(dummyERC721)),
            0,
            erc721TransferCall,
            address(tokenCollection),
            tokenId
        );

        assertEq(dummyERC721.balanceOf(vaultAddress), 0);
        assertEq(dummyERC721.balanceOf(user1), 1);
        assertEq(dummyERC721.ownerOf(1), user1);
    }

    function testNonOwnerCallsFail() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        uint256 tokenId = 9;

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        vm.deal(vaultAddress, 1 ether);

        Vault vault = Vault(vaultAddress);

        // should fail if user2 tries to use vault
        vm.prank(user2);
        vm.expectRevert(bytes("Not owner"));
        (bool success, ) = vault.execTransaction(
            payable(user2),
            0.1 ether,
            "",
            address(tokenCollection),
            tokenId
        );

        assertEq(success, false);
    }

    function testVaultOwnershipTransfer() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        uint256 tokenId = 10;

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        vm.deal(vaultAddress, 1 ether);

        Vault vault = Vault(vaultAddress);

        // should fail if user2 tries to use vault
        vm.prank(user2);
        vm.expectRevert(bytes("Not owner"));
        (bool success1, ) = vault.execTransaction(
            payable(user2),
            0.1 ether,
            "",
            address(tokenCollection),
            tokenId
        );

        assertEq(success1, false);

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, user2, tokenId);

        // should succeed now that user2 is owner
        vm.prank(user2);
        (bool success2, ) = vault.execTransaction(
            payable(user2),
            0.1 ether,
            "",
            address(tokenCollection),
            tokenId
        );

        assertEq(success2, true);
        assertEq(user2.balance, 0.1 ether);
    }

    function testMessageSigningAndVerificationForAuthorizedUser() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 11;

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(vaultAddress);

        bytes32 hash = keccak256("This is a signed message");
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, hash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        bytes4 returnValue1 = vault.isValidSignature(
            hash,
            signature1,
            address(tokenCollection),
            tokenId
        );

        assertEq(returnValue1, vault.isValidSignature.selector);
    }

    function testMessageSigningAndVerificationForUnauthorizedUser() public {
        address user1 = vm.addr(1);
        uint256 tokenId = 11;

        tokenCollection.mint(user1, tokenId);
        assertEq(tokenCollection.ownerOf(tokenId), user1);

        address payable vaultAddress = vaultRegistry.deployVault(
            address(tokenCollection),
            tokenId
        );

        Vault vault = Vault(vaultAddress);

        bytes32 hash = keccak256("This is a signed message");

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(2, hash);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes4 returnValue2 = vault.isValidSignature(
            hash,
            signature2,
            address(tokenCollection),
            tokenId
        );

        assertEq(returnValue2, 0);
    }
}

contract TokenCollection is ERC721 {
    constructor() ERC721("TokenCollection", "TC") {}

    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}

contract DummyERC721 is ERC721 {
    constructor() ERC721("DummyERC721", "T721") {}

    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}

contract DummyERC1155 is ERC1155 {
    constructor() ERC1155("http://DummyERC1155.com") {}

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external {
        _mint(to, tokenId, amount, "");
    }
}

contract DummyERC20 is ERC20 {
    constructor() ERC20("DummyERC20", "T20") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
