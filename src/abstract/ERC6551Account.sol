// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "erc6551/lib/ERC6551AccountLib.sol";
import "erc6551/interfaces/IERC6551Account.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./Validator.sol";
import "./Hooks.sol";

import "./StorageAccess.sol";

abstract contract ERC6551Account is IERC6551Account, StorageAccess, Validator, Hooks {
    receive() external payable {}

    function state() external view returns (uint256) {
        return _getState();
    }

    function isValidSigner(address signer, bytes calldata data) external view returns (bytes4 magicValue) {
        if (_isValidSigner(signer, data)) {
            return IERC6551Account.isValidSigner.selector;
        }

        return bytes4(0);
    }

    function token() public view returns (uint256 chainId, address tokenContract, uint256 tokenId) {
        return ERC6551AccountLib.token();
    }

    function _beforeExecute(address to, uint256 value, bytes calldata data, uint256 operation)
        internal
        virtual
        override
    {
        uint256 _state = _getState();
        bytes32 executionHash = keccak256(abi.encode(to, value, data, operation));
        _setState(uint256(keccak256(abi.encode(_state, executionHash))));
    }
}
