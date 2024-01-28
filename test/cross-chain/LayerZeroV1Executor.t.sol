// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "erc6551/ERC6551Registry.sol";

import "../mocks/MockERC721.sol";
import "../../src/AccountV3.sol";
import "../../src/AccountV3Upgradable.sol";
import "../../src/AccountGuardian.sol";
import "../../src/AccountProxy.sol";

import "layerzero-v1/lzApp/mocks/LZEndpointMock.sol";
import "../../src/cross-chain/LayerZeroV1Executor.sol";

contract LayerZeroV1ExecutorTest is Test {
    AccountV3 implementation;
    AccountV3Upgradable upgradableImplementation;
    AccountProxy proxy;
    ERC6551Registry public registry;
    AccountGuardian public guardian;

    MockERC721 public tokenCollection;

    LZEndpointMock endpoint;
    LayerZeroV1Executor executor;

    function setUp() public {
        endpoint = new LZEndpointMock(uint16(block.chainid));
        executor = new LayerZeroV1Executor(address(endpoint));

        registry = new ERC6551Registry();

        guardian = new AccountGuardian(address(this));
        implementation = new AccountV3(
            address(1), address(2), address(registry), address(guardian)
        );
        upgradableImplementation = new AccountV3Upgradable(
            address(1), address(2), address(registry), address(guardian)
        );
        proxy = new AccountProxy(address(guardian), address(upgradableImplementation));

        tokenCollection = new MockERC721();

        // mint tokenId 1 during setup for accurate cold call gas measurement
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        tokenCollection.mint(user1, tokenId);

        // enable lz executor
        guardian.setTrustedExecutor(address(executor), true);
    }

    function testLZCrossChainCall() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        console.log(address(this));
        console.log(address(endpoint));
        console.log(address(executor));

        // destination chain id
        uint256 chainId = block.chainid + 1;
        address accountAddress = registry.createAccount(
            address(implementation), 0, chainId, address(tokenCollection), tokenId
        );
        console.log(address(accountAddress));

        vm.deal(user1, 1 ether);
        vm.deal(accountAddress, 1 ether);
        endpoint.setDestLzEndpoint(address(executor), address(endpoint));

        bytes memory adapterParams = endpoint.defaultAdapterParams();
        bytes memory dstCallData = abi.encodeWithSignature(
            "execute(address,uint256,bytes,uint8)", user2, 0.1 ether, "", LibExecutor.OP_CALL
        );

        (uint256 fee,) = endpoint.estimateFees(
            uint16(chainId), accountAddress, dstCallData, false, adapterParams
        );

        // send from TBA on origin chain
        vm.prank(accountAddress);
        endpoint.send{value: fee}(
            uint16(chainId),
            abi.encodePacked(executor, accountAddress),
            dstCallData,
            payable(accountAddress),
            address(0),
            adapterParams
        );

        // destination call is executed
        assertEq(user2.balance, 0.1 ether);

        // send from non-tba caller
        vm.prank(user1);
        endpoint.send{value: fee}(
            uint16(chainId),
            abi.encodePacked(executor, accountAddress),
            dstCallData,
            payable(accountAddress),
            address(0),
            adapterParams
        );

        // destination call is not executed
        assertEq(user2.balance, 0.1 ether);
    }
}
