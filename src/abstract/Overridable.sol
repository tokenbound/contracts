// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "../utils/Errors.sol";
import "../lib/LibSandbox.sol";

abstract contract Overridable {
    /// @dev mapping from owner => selector => implementation
    mapping(address => mapping(bytes4 => address)) public overrides;

    event OverrideUpdated(address owner, bytes4 selector, address implementation);

    /// @dev sets the implementation address for a given function call
    function setOverrides(bytes4[] calldata selectors, address[] calldata implementations) external virtual {
        address _owner = _getStorageOwner();

        if (_owner == address(0)) revert NotAuthorized();

        if (!_canSetOverrides()) revert NotAuthorized();

        _beforeSetOverrides();

        address sandbox = LibSandbox.sandbox(address(this));
        if (sandbox.code.length == 0) LibSandbox.deploy(address(this));

        uint256 length = selectors.length;

        if (implementations.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            overrides[_owner][selectors[i]] = implementations[i];
            emit OverrideUpdated(_owner, selectors[i], implementations[i]);
        }
    }

    function _handleOverride() internal virtual {
        address _owner = _getStorageOwner();

        address implementation = overrides[_owner][msg.sig];

        if (implementation != address(0)) {
            address sandbox = LibSandbox.sandbox(address(this));
            (bool success, bytes memory result) = sandbox.call(abi.encodePacked(implementation, msg.data));
            assembly {
                if iszero(success) { revert(add(result, 32), mload(result)) }
                return(add(result, 32), mload(result))
            }
        }
    }

    function _handleOverrideStatic() internal view virtual {
        address _owner = _getStorageOwner();
        address implementation = overrides[_owner][msg.sig];

        if (implementation != address(0)) {
            (bool success, bytes memory result) = implementation.staticcall(msg.data);
            assembly {
                if iszero(success) { revert(add(result, 32), mload(result)) }
                return(add(result, 32), mload(result))
            }
        }
    }

    function _beforeSetOverrides() internal virtual {}

    function _getStorageOwner() internal view virtual returns (address);

    function _canSetOverrides() internal view virtual returns (bool);
}
