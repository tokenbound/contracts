// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "./abstract/AssetReceiver.sol";
import "./abstract/Lockable.sol";
import "./abstract/Overridable.sol";
import "./abstract/Permissioned.sol";
import "./abstract/ERC6551Account.sol";
import "./abstract/ERC4337Account.sol";

contract AccountV3 is AssetReceiver, Lockable, Overridable, Permissioned, ERC6551Account, ERC4337Account {
    constructor(address entryPoint_, address multicallForwarder, address erc6551Registry)
        ERC4337Account(entryPoint_)
        Executor(multicallForwarder, erc6551Registry)
    {}

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver, ERC6551Account)
        returns (bool)
    {
        bool interfaceSupported = super.supportsInterface(interfaceId);

        if (interfaceSupported) return true;

        _handleOverrideStatic();

        return false;
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        _handleOverrideStatic();
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        _handleOverrideStatic();
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        _handleOverrideStatic();
        return this.onERC1155BatchReceived.selector;
    }

    function _isValidSigner(address signer, bytes memory) internal view virtual override returns (bool) {
        return signer == owner() || hasPermission(signer);
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
        return _isValidSigner(_msgSender(), "");
    }

    function _beforeLock() internal override {
        if (isLocked()) revert AccountLocked();
        _transitionState();
    }

    function _canSetOverrides() internal view virtual override returns (bool) {
        return _isValidSigner(_msgSender(), "");
    }

    function _beforeSetOverrides() internal override {
        if (isLocked()) revert AccountLocked();
        _transitionState();
    }

    function _canSetPermissions() internal view virtual override returns (bool) {
        return _isValidSigner(_msgSender(), "");
    }

    function _beforeSetPermissions() internal override {
        if (isLocked()) revert AccountLocked();
        _transitionState();
    }
}
