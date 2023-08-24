// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/Errors.sol";
import "./StorageAccess.sol";
import "./Validator.sol";

abstract contract Permissioned is StorageAccess, Validator {
    event PermissionUpdated(address owner, address caller, bool hasPermission);

    /// @dev grants a given caller execution permissions
    function setPermissions(address[] calldata callers, bool[] calldata _permissions) external virtual {}
}
