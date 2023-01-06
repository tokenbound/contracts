// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/Create2.sol";
import "sstore2/utils/Bytecode.sol";

library MinimalProxyStore {
    error CreateError();
    error ContextOverflow();

    /**
     * @dev Returns bytecode for a minmal proxy with additional context data appended to it
     * @param implementation the implementation this proxy will delegate to
     * @param context the data to be appended to the proxy
     * @return the generated bytecode
     */
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

    /**
     * @dev Fetches the context data stored in a deployed proxy
     * @param instance the proxy to query context data for
     * @param contextSize the length in bytes of the data that should be queried
     * @return the queried context data
     */
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

    /**
     * @dev Deploys and returns the address of a clone with stored context data that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     *
     * @param implementation the implementation to delegate to
     * @param context context data to be stored in the proxy
     * @return instance the address of the deployed proxy
     */
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

    /**
     * @dev Deploys and returns the address of a clone with stored context data that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     *
     * @param implementation the implementation to delegate to
     * @param context context data to be stored in the proxy
     * @return instance the address of the deployed proxy
     */
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

    /**
     * @dev Computes the address of a clone deployed using {MinimalProxyStore-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes memory context,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes memory code = getBytecode(implementation, context);

        return Create2.computeAddress(salt, keccak256(code), deployer);
    }

    /**
     * @dev Computes the address of a clone deployed using {MinimalProxyStore-cloneDeterministic}.
     */
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
