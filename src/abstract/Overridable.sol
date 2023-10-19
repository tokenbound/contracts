// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "erc6551/lib/ERC6551AccountLib.sol";

import "../utils/Errors.sol";
import "../lib/LibSandbox.sol";

/**
 * @title Account Overrides
 * @dev Allows the root owner of a token bound account to override the implementation of a given
 * function selector on the account. Overrides are keyed by the root owner address, so will be
 * disabled upon transfer of the token which owns this account tree.
 */
abstract contract Overridable {
    /**
     * @dev mapping from owner => selector => implementation
     */
    mapping(address => mapping(bytes4 => address)) public overrides;

    event OverrideUpdated(address owner, bytes4 selector, address implementation);

    /**
     * @dev Sets the implementation address for a given array of function selectors. Can only be
     * called by the root owner of the account
     *
     * @param selectors Array of selectors to override
     * @param implementations Array of implementation address corresponding to selectors
     */
    function setOverrides(bytes4[] calldata selectors, address[] calldata implementations)
        external
        virtual
    {
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        address _owner = _rootTokenOwner(chainId, tokenContract, tokenId);

        if (_owner == address(0)) revert NotAuthorized();
        if (msg.sender != _owner) revert NotAuthorized();

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

    /**
     * @dev Calls into the implementation address using sandbox if override is set for the current
     * function selector. If an implementation is defined, this funciton will either revert or
     * return with the return value of the implementation
     */
    function _handleOverride() internal virtual {
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        address _owner = _rootTokenOwner(chainId, tokenContract, tokenId);

        address implementation = overrides[_owner][msg.sig];

        if (implementation != address(0)) {
            address sandbox = LibSandbox.sandbox(address(this));
            (bool success, bytes memory result) =
                sandbox.call(abi.encodePacked(implementation, msg.data, msg.sender));
            assembly {
                if iszero(success) { revert(add(result, 32), mload(result)) }
                return(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Static calls into the implementation addressif override is set for the current function
     * selector. If an implementation is defined, this funciton will either revert or return with
     * the return value of the implementation
     */
    function _handleOverrideStatic() internal view virtual {
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        address _owner = _rootTokenOwner(chainId, tokenContract, tokenId);

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

    function _rootTokenOwner(uint256 chainId, address tokenContract, uint256 tokenId)
        internal
        view
        virtual
        returns (address);
}
