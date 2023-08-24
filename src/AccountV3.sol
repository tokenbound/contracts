// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "./abstract/Storage.sol";
import "./abstract/ERC6551Account.sol";
import "./abstract/AssetReceiver.sol";
import "./abstract/Signatory.sol";
import "./abstract/Executor.sol";
import "./abstract/SandboxExecutor.sol";
import "./abstract/ERC4337Account.sol";
import "./abstract/Overridable.sol";
import "./abstract/Permissioned.sol";
import "./abstract/Lockable.sol";

contract AccountV3 is
    Storage,
    Lockable,
    Overridable,
    Permissioned,
    ERC6551Account,
    AssetReceiver,
    Signatory,
    Executor,
    SandboxExecutor,
    ERC4337Account
{
    constructor(address entryPoint_) ERC4337Account(entryPoint_) {}

    fallback() external payable {}

    function owner() public view override returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();

        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function _isValidSigner(address signer, bytes memory) internal view override returns (bool) {
        return signer == owner();
    }

    function _isValidSignature(bytes32 hash, bytes calldata signature) internal view override returns (bool) {
        return SignatureChecker.isValidSignatureNow(owner(), hash, signature);
    }

    function _isValidExecutor(address executor, address, uint256, bytes calldata, uint256)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return executor == address(entryPoint()) || _isValidSigner(executor, "");
    }
}
