// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/lib/MinimalProxyStore.sol";

contract TestContract {
    function test() public pure returns (uint256) {
        return 123;
    }
}

contract MinimalProxyStoreTest is Test {
    function testDeploymentSucceeds() public {
        TestContract testContract = new TestContract();

        address clone = MinimalProxyStore.clone(
            address(testContract),
            abi.encode("hello")
        );

        assertTrue(clone != address(0));
        assertEq(TestContract(clone).test(), 123);
    }

    function testGetContext() public {
        TestContract testContract = new TestContract();

        bytes memory context = abi.encode("hello");

        address clone = MinimalProxyStore.clone(address(testContract), context);

        assertTrue(clone != address(0));
        assertEq(TestContract(clone).test(), 123);

        bytes memory recoveredContext = MinimalProxyStore.getContext(
            clone,
            context.length
        );

        assertEq(recoveredContext, context);
    }

    function testCreate2() public {
        TestContract testContract = new TestContract();

        bytes memory context = abi.encode("hello");

        address clone = MinimalProxyStore.cloneDeterministic(
            address(testContract),
            context,
            keccak256("hello")
        );

        assertTrue(clone != address(0));
        assertEq(TestContract(clone).test(), 123);

        bytes memory recoveredContext = MinimalProxyStore.getContext(
            clone,
            context.length
        );

        assertEq(recoveredContext, context);

        address predictedAddress = MinimalProxyStore
            .predictDeterministicAddress(
                address(testContract),
                context,
                keccak256("hello")
            );

        assertEq(clone, predictedAddress);
    }

    function testRedeploymentFails() public {
        TestContract testContract = new TestContract();

        bytes memory context = abi.encode("hello");

        MinimalProxyStore.cloneDeterministic(
            address(testContract),
            context,
            keccak256("hello")
        );
        vm.expectRevert(MinimalProxyStore.CreateError.selector);
        MinimalProxyStore.cloneDeterministic(
            address(testContract),
            context,
            keccak256("hello")
        );
    }

    function testCannotOverflowContext() public {
        bytes memory largeContext = new bytes(211);

        vm.expectRevert(MinimalProxyStore.ContextOverflow.selector);
        MinimalProxyStore.getBytecode(address(this), largeContext);

        vm.expectRevert(MinimalProxyStore.ContextOverflow.selector);
        MinimalProxyStore.getContext(address(this), 211);
    }
}
