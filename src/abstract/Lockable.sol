// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/Errors.sol";

abstract contract Lockable {
    /// @dev timestamp at which this account will be unlocked
    uint256 public lockedUntil;

    event LockUpdated(uint256 lockedUntil);

    /// @dev locks the account until a certain timestamp
    function lock(uint256 _lockedUntil) external virtual {
        if (!_canLockAccount()) revert NotAuthorized();

        if (_lockedUntil > block.timestamp + 365 days) {
            revert ExceedsMaxLockTime();
        }

        _beforeLock();

        lockedUntil = _lockedUntil;

        emit LockUpdated(_lockedUntil);
    }

    /// @dev returns the current lock status of the account as a boolean
    function isLocked() public view virtual returns (bool) {
        return lockedUntil > block.timestamp;
    }

    function _canLockAccount() internal view virtual returns (bool);

    function _beforeLock() internal virtual {}
}
