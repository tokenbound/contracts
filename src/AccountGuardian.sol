// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable2Step.sol";

// @dev manages upgrade and cross-chain execution settings for accounts
contract AccountGuardian is Ownable2Step {
    // @dev the default implementation that will be used by all new accounts
    address public defaultImplementation;

    // @dev mapping from cross-chain executor => is trusted
    mapping(address => bool) public isTrustedImplementation;

    // @dev mapping from implementation => is trusted
    mapping(address => bool) public isTrustedExecutor;

    event DefaultImplementationUpdated(address implementation);
    event TrustedImplementationUpdated(address implementation, bool trusted);
    event TrustedExecutorUpdated(address executor, bool trusted);

    function setDefaultImplementation(address implementation)
        external
        onlyOwner
    {
        defaultImplementation = implementation;
        emit DefaultImplementationUpdated(implementation);
    }

    function setTrustedImplementation(address implementation, bool trusted)
        external
        onlyOwner
    {
        isTrustedImplementation[implementation] = trusted;
        emit TrustedImplementationUpdated(implementation, trusted);
    }

    function setTrustedExecutor(address executor, bool trusted)
        external
        onlyOwner
    {
        isTrustedExecutor[executor] = trusted;
        emit TrustedExecutorUpdated(executor, trusted);
    }
}
