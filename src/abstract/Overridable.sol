// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/Errors.sol";
import "../lib/LibSandbox.sol";
import "./ERC5313.sol";
import "./StorageAccess.sol";
import "./Validator.sol";

abstract contract Overridable is ERC5313, StorageAccess, Validator {
    event OverrideUpdated(address owner, bytes4 selector, address implementation);

    /// @dev sets the implementation address for a given function call
    function setOverrides(bytes4[] calldata selectors, address[] calldata implementations) external virtual {
        address _owner = owner();
        if (msg.sender != _owner) revert NotAuthorized();

        uint256 length = selectors.length;

        if (implementations.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            _setOverride(_owner, selectors[i], implementations[i]);
            emit OverrideUpdated(_owner, selectors[i], implementations[i]);
        }

        // TODO: update state
    }

    function _handleOverride() internal virtual {
        address implementation = _getOverride(owner(), msg.sig);

        if (implementation != address(0)) {
            address sandbox = LibSandbox.sandbox(address(this));
            (bool success, bytes memory result) = implementation.call(abi.encodePacked(sandbox, msg.data));
            assembly {
                if iszero(success) { revert(add(result, 32), mload(result)) }
                return(add(result, 32), mload(result))
            }
        }
    }

    function _handleOverrideStatic() internal view virtual {
        address implementation = _getOverride(owner(), msg.sig);

        if (implementation != address(0)) {
            (bool success, bytes memory result) = implementation.staticcall(msg.data);
            assembly {
                if iszero(success) { revert(add(result, 32), mload(result)) }
                return(add(result, 32), mload(result))
            }
        }
    }
}
