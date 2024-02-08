// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import {TestHelper as LZTestHelper} from "layerzero-v2/oapp/test/TestHelper.sol";
import {
    ILayerZeroEndpointV2,
    MessagingParams,
    MessagingFee
} from "layerzero-v2/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "layerzero-v2/oapp/contracts/oapp/libs/OptionsBuilder.sol";

import "erc6551/ERC6551Registry.sol";

import "../mocks/MockERC721.sol";
import "../../src/AccountV3.sol";
import "../../src/AccountV3Upgradable.sol";
import "../../src/AccountGuardian.sol";
import "../../src/AccountProxy.sol";

import "../../src/cross-chain/LayerZeroV2Executor.sol";

contract LayerZeroV2ExecutorTest is LZTestHelper {
    using OptionsBuilder for bytes;

    AccountV3 implementation;
    AccountV3Upgradable upgradableImplementation;
    AccountProxy proxy;
    ERC6551Registry public registry;
    AccountGuardian public guardian;

    MockERC721 public tokenCollection;

    LayerZeroV2Executor executor;

    uint32 originEid = 1;
    uint32 destinationEid = 2;

    function setUp() public override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        executor = new LayerZeroV2Executor(endpoints[destinationEid]);

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

    function testLZV2CrossChainCall() public {
        uint256 tokenId = 1;
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        console.log(address(this));
        console.log(address(executor));

        // destination chain id
        uint256 chainId = block.chainid + 1;
        address accountAddress = registry.createAccount(
            address(implementation), 0, chainId, address(tokenCollection), tokenId
        );

        console.log(accountAddress);

        vm.deal(user1, 1 ether);
        vm.deal(accountAddress, 1 ether);

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        bytes memory dstCallData = abi.encodeWithSignature(
            "execute(address,uint256,bytes,uint8)", user2, 0.1 ether, "", LibExecutor.OP_CALL
        );
        MessagingParams memory params = MessagingParams(
            destinationEid, addressToBytes32(address(executor)), dstCallData, options, false
        );

        MessagingFee memory fee =
            ILayerZeroEndpointV2(endpoints[originEid]).quote(params, accountAddress);

        // send from TBA on origin chain
        vm.prank(accountAddress);
        ILayerZeroEndpointV2(endpoints[originEid]).send{value: fee.nativeFee}(
            params, accountAddress
        );

        verifyPackets(destinationEid, addressToBytes32(address(executor)));

        // destination call is executed
        assertEq(user2.balance, 0.1 ether);

        // send from non-tba caller
        vm.prank(user1);
        ILayerZeroEndpointV2(endpoints[originEid]).send{value: fee.nativeFee}(
            params, accountAddress
        );

        verifyPackets(destinationEid, addressToBytes32(address(executor)));

        // destination call is not executed
        assertEq(user2.balance, 0.1 ether);
    }
}
