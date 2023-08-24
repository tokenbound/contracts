// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "./abstract/AssetReceiver.sol";
import "./abstract/Lockable.sol";
import "./abstract/Overridable.sol";
import "./abstract/Permissioned.sol";
import "./abstract/ERC6551Account.sol";
import "./abstract/ERC4337Account.sol";

contract AccountV3 is AssetReceiver, Lockable, Overridable, Permissioned, ERC6551Account, ERC4337Account {
    constructor(address entryPoint_) ERC4337Account(entryPoint_) {}

    receive() external payable override {
        _handleOverride();
    }

    fallback() external payable {
        _handleOverride();
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();

        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function _isValidSigner(address signer, bytes memory) internal view virtual override returns (bool) {
        return signer == owner();
    }

    function _isValidSignature(bytes32 hash, bytes calldata signature)
        internal
        view
        override(ERC4337Account, Signatory)
        returns (bool)
    {
        return SignatureChecker.isValidSignatureNow(owner(), hash, signature);
    }

    function _isValidExecutor(address executor) internal view virtual override returns (bool) {
        return executor == address(entryPoint()) || _isValidSigner(executor, "");
    }

    function _beforeExecute() internal override {
        if (isLocked()) revert AccountLocked();
        _transitionState();
    }

    function _getStorageOwner() internal view virtual override(Overridable, Permissioned) returns (address) {
        return owner();
    }

    function _canLockAccount() internal view virtual override returns (bool) {
        return _isValidSigner(msg.sender, "");
    }

    function _beforeLock() internal override {
        if (isLocked()) revert AccountLocked();
        _transitionState();
    }

    function _canSetOverrides() internal view virtual override returns (bool) {
        return _isValidSigner(msg.sender, "");
    }

    function _beforeSetOverrides() internal override {
        if (isLocked()) revert AccountLocked();
        _transitionState();
    }

    function _canSetPermissions() internal view virtual override returns (bool) {
        return _isValidSigner(msg.sender, "");
    }

    function _beforeSetPermissions() internal override {
        if (isLocked()) revert AccountLocked();
        _transitionState();
    }
}
