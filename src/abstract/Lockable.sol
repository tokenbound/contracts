// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract Lockable {
    event LockUpdated(uint256 lockedUntil);

    /// @dev locks the account until a certain timestamp
    function lock(uint256 _lockedUntil) external virtual {}

    /// @dev returns the current lock status of the account as a boolean
    function isLocked() public view virtual returns (bool) {}
}
