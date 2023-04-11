// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable2Step.sol";

// @dev manages upgrade and cross-chain execution settings for accounts
contract AccountGuardian is Ownable2Step {
    // @dev mapping from cross-chain executor => is trusted
    mapping(address => bool) public isTrustedImplementation;

    // @dev mapping from implementation => is trusted
    mapping(address => bool) public isTrustedExecutor;

    function setTrustedImplementation(address implementation, bool trusted)
        external
        onlyOwner
    {
        isTrustedImplementation[implementation] = trusted;
    }

    function setTrustedExecutor(address executor, bool trusted)
        external
        onlyOwner
    {
        isTrustedExecutor[executor] = trusted;
    }
}
