// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "erc6551/lib/ERC6551AccountLib.sol";
import "../utils/Errors.sol";

/**
 * @title Account Permissions
 * @dev Allows the root owner of a token bound account to allow another account to execute
 * operations from this account. Permissions are keyed by the root owner address, so will be
 * disabled upon transfer of the token which owns this account tree.
 */
abstract contract Permissioned {
    /**
     * @dev mapping from owner => caller => has permissions
     */
    mapping(address => mapping(address => bool)) public permissions;

    event PermissionUpdated(address owner, address caller, bool hasPermission);

    /**
     * @dev Grants or revokes execution permissions for a given array of callers on this account.
     * Can only be called by the root owner of the account
     *
     * @param callers Array of callers to grant permissions to
     * @param _permissions Array of booleans, true if execution permissions should be granted,
     * false if permissions should be revoked
     */
    function setPermissions(address[] calldata callers, bool[] calldata _permissions)
        external
        virtual
    {
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        address _owner = _rootTokenOwner(chainId, tokenContract, tokenId);

        if (_owner == address(0)) revert NotAuthorized();
        if (msg.sender != _owner) revert NotAuthorized();

        _beforeSetPermissions();

        uint256 length = callers.length;

        if (_permissions.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            permissions[_owner][callers[i]] = _permissions[i];
            emit PermissionUpdated(_owner, callers[i], _permissions[i]);
        }
    }

    /**
     * @dev Returns true if caller has permissions to act on behalf of owner
     *
     * @param caller Address to query permissions for
     * @param owner Root owner address for which to query permissions
     */
    function hasPermission(address caller, address owner) internal view returns (bool) {
        return permissions[owner][caller];
    }

    function _beforeSetPermissions() internal virtual {}

    function _rootTokenOwner(uint256 chainId, address tokenContract, uint256 tokenId)
        internal
        view
        virtual
        returns (address);
}
