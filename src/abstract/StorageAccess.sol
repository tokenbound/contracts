// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract StorageAccess {
    function _getLockedUntil() internal view virtual returns (uint256);
    function _setLockedUntil(uint256 value) internal virtual;

    function _getOverride(address owner, bytes4 selector) internal view virtual returns (address);
    function _setOverride(address owner, bytes4 selector, address _override) internal virtual;

    function _getPermission(address owner, address caller) internal view virtual returns (bool);
    function _setPermission(address owner, address caller, bool permission) internal virtual;

    function _getState() internal view virtual returns (uint256);
    function _setState(uint256 value) internal virtual;

    function _getDepositor() internal view virtual returns (address);
    function _setDepositor(address depositor) internal virtual;
}
