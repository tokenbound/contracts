// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/CrossChainExecutorList.sol";
import "../src/lib/MinimalProxyStore.sol";

contract AccountRegistryTest is Test {
    CrossChainExecutorList public crossChainExecutorList;

    function setUp() public {
        crossChainExecutorList = new CrossChainExecutorList();
    }

    function testSetCrossChainExecutor() public {
        address crossChainExecutor = vm.addr(1);
        address notCrossChainExecutor = vm.addr(2);

        crossChainExecutorList.setCrossChainExecutor(
            block.chainid,
            crossChainExecutor,
            true
        );

        assertTrue(
            crossChainExecutorList.isCrossChainExecutor(
                block.chainid,
                crossChainExecutor
            )
        );
        assertEq(
            crossChainExecutorList.isCrossChainExecutor(
                block.chainid,
                notCrossChainExecutor
            ),
            false
        );

        crossChainExecutorList.setCrossChainExecutor(
            block.chainid,
            crossChainExecutor,
            false
        );
        assertEq(
            crossChainExecutorList.isCrossChainExecutor(
                block.chainid,
                crossChainExecutor
            ),
            false
        );
    }
}
