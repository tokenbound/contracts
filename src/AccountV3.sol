// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "./abstract/AssetReceiver.sol";
import "./abstract/Lockable.sol";
import "./abstract/Overridable.sol";
import "./abstract/Permissioned.sol";
import "./abstract/ERC6551Account.sol";
import "./abstract/ERC4337Account.sol";
import "./abstract/execution/TokenboundExecutor.sol";

contract AccountV3 is
    AssetReceiver,
    Lockable,
    Overridable,
    Permissioned,
    ERC6551Account,
    ERC4337Account,
    TokenboundExecutor
{
    constructor(address entryPoint_, address multicallForwarder, address erc6551Registry)
        ERC4337Account(entryPoint_)
        TokenboundExecutor(multicallForwarder, erc6551Registry)
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
        if (tokenContract.code.length == 0) return address(0);

        try IERC721(tokenContract).ownerOf(tokenId) returns (address _owner) {
            return _owner;
        } catch {
            return address(0);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver, ERC6551Account, ERC6551Executor)
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
        uint8 v = uint8(signature[64]);
        address signer;

        // Smart contract signature
        if (v == 0) {
            // Signer address encoded in r
            signer = address(uint160(uint256(bytes32(signature[:32]))));

            // Allow recursive signature verification
            if (!_isValidSigner(signer, "") && signer != address(this)) return false;

            // Signature offset encoded in s
            bytes calldata _signature = signature[uint256(bytes32(signature[32:64])):];

            return SignatureChecker.isValidERC1271SignatureNow(signer, hash, _signature);
        }

        ECDSA.RecoverError _error;
        (signer, _error) = ECDSA.tryRecover(hash, signature);

        if (_error != ECDSA.RecoverError.NoError) return false;

        return _isValidSigner(signer, "");
    }

    function _isValidExecutor(address executor) internal view virtual override returns (bool) {
        if (executor == address(entryPoint())) return true;

        return _isValidSigner(executor, "");
    }

    function _transitionState() internal virtual {
        _state = uint256(keccak256(abi.encode(_state, keccak256(_msgData()))));
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
