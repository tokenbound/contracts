// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "erc6551/lib/ERC6551AccountLib.sol";
import "erc6551/interfaces/IERC6551Account.sol";

import "./Signatory.sol";
import "./Executor.sol";

abstract contract ERC6551Account is IERC6551Account, Executor, Signatory {
    uint256 _state;

    receive() external payable virtual {}

    function isValidSigner(address signer, bytes calldata data) external view returns (bytes4 magicValue) {
        if (_isValidSigner(signer, data)) {
            return IERC6551Account.isValidSigner.selector;
        }

        return bytes4(0);
    }

    function token() public view returns (uint256 chainId, address tokenContract, uint256 tokenId) {
        return ERC6551AccountLib.token();
    }

    function state() public view returns (uint256) {
        return _state;
    }

    function _transitionState() internal {
        _state = uint256(keccak256(abi.encode(_state, keccak256(msg.data))));
    }

    function _isValidSigner(address signer, bytes memory) internal view virtual returns (bool);
}
