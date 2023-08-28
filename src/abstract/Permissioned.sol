// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/Errors.sol";

abstract contract Permissioned {
    /// @dev mapping from owner => caller => has permissions
    mapping(address => mapping(address => bool)) public permissions;

    event PermissionUpdated(address owner, address caller, bool hasPermission);

    /// @dev grants a given caller execution permissions
    function setPermissions(address[] calldata callers, bool[] calldata _permissions)
        external
        virtual
    {
        address _owner = _getStorageOwner();

        if (_owner == address(0)) revert NotAuthorized();

        if (!_canSetPermissions()) revert NotAuthorized();

        _beforeSetPermissions();

        uint256 length = callers.length;

        if (_permissions.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            permissions[_owner][callers[i]] = _permissions[i];
            emit PermissionUpdated(_owner, callers[i], _permissions[i]);
        }
    }

    function hasPermission(address caller) internal view returns (bool) {
        address _owner = _getStorageOwner();
        return permissions[_owner][caller];
    }

    function _beforeSetPermissions() internal virtual {}

    function _getStorageOwner() internal view virtual returns (address);

    function _canSetPermissions() internal view virtual returns (bool);
}
