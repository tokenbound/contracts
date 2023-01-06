// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/Create2.sol";
import "sstore2/utils/Bytecode.sol";

library MinimalProxyStore {
    error CreateError();
    error ContextOverflow();

    function getBytecode(address implementation, bytes memory context)
        internal
        pure
        returns (bytes memory)
    {
        if (context.length > 210) revert ContextOverflow();

        return
            abi.encodePacked(
                hex"3d60",
                uint8(0x2d + context.length + 1),
                hex"80600a3d3981f3363d3d373d3d3d363d73",
                implementation,
                hex"5af43d82803e903d91602b57fd5bf3",
                hex"00",
                context
            );
    }

    function getContext(address instance, uint256 contextSize)
        internal
        view
        returns (bytes memory)
    {
        if (contextSize > 210) revert ContextOverflow();

        uint256 instanceCodeLength = instance.code.length;

        return
            Bytecode.codeAt(
                instance,
                instanceCodeLength - contextSize,
                instanceCodeLength
            );
    }

    function clone(address implementation, bytes memory context)
        internal
        returns (address instance)
    {
        // Generate bytecode for proxy
        bytes memory code = getBytecode(implementation, context);

        // Deploy contract using create
        assembly {
            instance := create(0, add(code, 32), mload(code))
        }

        // If address is zero, deployment failed
        if (instance == address(0)) revert CreateError();
    }

    function cloneDeterministic(
        address implementation,
        bytes memory context,
        bytes32 salt
    ) internal returns (address instance) {
        bytes memory code = getBytecode(implementation, context);

        // Deploy contract using create2
        assembly {
            instance := create2(0, add(code, 32), mload(code), salt)
        }

        // If address is zero, deployment failed
        if (instance == address(0)) revert CreateError();
    }

    function predictDeterministicAddress(
        address implementation,
        bytes memory context,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes memory code = getBytecode(implementation, context);

        return Create2.computeAddress(salt, keccak256(code), deployer);
    }

    function predictDeterministicAddress(
        address implementation,
        bytes memory context,
        bytes32 salt
    ) internal view returns (address predicted) {
        return
            predictDeterministicAddress(
                implementation,
                context,
                salt,
                address(this)
            );
    }
}
