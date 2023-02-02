// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable2Step.sol";

contract CrossChainExecutorList is Ownable2Step {
    mapping(uint256 => mapping(address => bool)) public isCrossChainExecutor;

    /**
     * @dev Enables or disables a trusted cross-chain executor.
     *
     * @param chainId the chainid of the network the executor exists on
     * @param executor the address of the executor
     * @param enabled true if executor should be enabled, false otherwise
     */
    function setCrossChainExecutor(
        uint256 chainId,
        address executor,
        bool enabled
    ) external onlyOwner {
        isCrossChainExecutor[chainId][executor] = enabled;
    }
}
