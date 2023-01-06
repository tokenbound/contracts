// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/lib/MinimalProxyStore.sol";

contract TestContract {
    error Failed();

    function test() public pure returns (uint256) {
        return 123;
    }

    function fails() public pure {
        revert Failed();
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

    function testReverts() public {
        TestContract testContract = new TestContract();

        address clone = MinimalProxyStore.clone(
            address(testContract),
            abi.encode("hello")
        );

        assertTrue(clone != address(0));
        vm.expectRevert(TestContract.Failed.selector);
        TestContract(clone).fails();
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

    // must run with --code-size-limit 24576
    function testCannotOverflowContext() public {
        uint256 maxSize = 0x6000 - 46;
        bytes memory maxSizeContext = new bytes(maxSize);
        bytes memory overflowContext = new bytes(maxSize + 1);

        MinimalProxyStore.clone(address(this), maxSizeContext);

        vm.expectRevert(MinimalProxyStore.CreateError.selector);
        MinimalProxyStore.clone(address(this), overflowContext);
    }
}
