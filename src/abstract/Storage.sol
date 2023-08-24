// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./StorageAccess.sol";

abstract contract Storage is StorageAccess {
    /// @dev timestamp at which this account will be unlocked
    uint256 public lockedUntil;

    /// @dev mapping from owner => selector => implementation
    mapping(address => mapping(bytes4 => address)) public overrides;

    /// @dev mapping from owner => caller => has permissions
    mapping(address => mapping(address => bool)) public permissions;

    /// @dev current state of the account
    uint256 _state;

    /// @dev address of the account which deposited account token
    address _depositor;

    function _getLockedUntil() internal view override returns (uint256) {
        return lockedUntil;
    }

    function _setLockedUntil(uint256 value) internal override {
        lockedUntil = value;
    }

    function _getOverride(address owner, bytes4 selector) internal view override returns (address) {
        return overrides[owner][selector];
    }

    function _setOverride(address owner, bytes4 selector, address _override) internal override {
        overrides[owner][selector] = _override;
    }

    function _getPermission(address owner, address caller) internal view override returns (bool) {
        return permissions[owner][caller];
    }

    function _setPermission(address owner, address caller, bool permission) internal override {
        permissions[owner][caller] = permission;
    }

    function _getState() internal view override returns (uint256) {
        return _state;
    }

    function _setState(uint256 value) internal override {
        _state = value;
    }

    function _getDepositor() internal view override returns (address) {
        return _depositor;
    }

    function _setDepositor(address depositor) internal override {
        _depositor = depositor;
    }
}
