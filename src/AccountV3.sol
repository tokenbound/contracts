// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./abstract/Lockable.sol";
import "./abstract/Overridable.sol";
import "./abstract/Permissioned.sol";
import "./abstract/ERC6551Account.sol";
import "./abstract/ERC4337Account.sol";
import "./abstract/execution/TokenboundExecutor.sol";

import "./lib/OPAddressAliasHelper.sol";

/**
 * @title Tokenbound ERC-6551 Account Implementation
 */
contract AccountV3 is
    ERC721Holder,
    ERC1155Holder,
    Lockable,
    Overridable,
    Permissioned,
    ERC6551Account,
    ERC4337Account,
    TokenboundExecutor
{
    /**
     * @param entryPoint_ The ERC-4337 EntryPoint address
     * @param multicallForwarder The MulticallForwarder address
     * @param erc6551Registry The ERC-6551 Registry address
     */
    constructor(address entryPoint_, address multicallForwarder, address erc6551Registry)
        ERC4337Account(entryPoint_)
        TokenboundExecutor(multicallForwarder, erc6551Registry)
    {}

    /**
     * @notice Called whenever this account received Ether
     *
     * @dev Can be overriden via Overridable
     */
    receive() external payable override {
        _handleOverride();
    }

    /**
     * @notice Called whenever the calldata function selector does not match a defined function
     *
     * @dev Can be overriden via Overridable
     */
    fallback() external payable {
        _handleOverride();
    }

    /**
     * @notice Returns the owner of the token this account is bound to (if available)
     *
     * @dev Returns zero address if token is on a foreign chain or token contract does not exist
     *
     * @return address The address which owns the token this account is bound to
     */
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

    /**
     * @notice Returns whether a given ERC165 interface ID is supported
     *
     * @dev Can be overriden via Overridable except for base interfaces.
     *
     * @param interfaceId The interface ID to query for
     * @return bool True if the interface is supported, false otherwise
     */
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

    /**
     * @dev called whenever an ERC-721 token is received. Can be overriden via Overridable.
     */
    function onERC721Received(address, address, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        _handleOverrideStatic();
        return this.onERC721Received.selector;
    }

    /**
     * @dev called whenever an ERC-1155 token is received. Can be overriden via Overridable.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        _handleOverrideStatic();
        return this.onERC1155Received.selector;
    }

    /**
     * @dev called whenever a batch of ERC-1155 tokens are received. Can be overriden via Overridable.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        _handleOverrideStatic();
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @notice Returns whether a given account is authorized to sign on behalf of this account
     *
     * @param signer The address to query authorization for
     * @return True if the signer is valid, false otherwise
     */
    function _isValidSigner(address signer, bytes memory)
        internal
        view
        virtual
        override
        returns (bool)
    {
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

    /**
     * @notice Returns whether a given account is authorized to execute transactions on behalf of
     * this account
     *
     * @param executor The address to query authorization for
     * @return True if the executor is authorized, false otherwise
     */
    function _isValidExecutor(address executor) internal view virtual override returns (bool) {
        // Allow execution from ERC-4337 EntryPoint
        if (executor == address(entryPoint())) return true;

        // Allow execution from L1 account on OPStack chains
        if (OPAddressAliasHelper.undoL1ToL2Alias(_msgSender()) == address(this)) return true;

        // Allow execution from valid signers
        return _isValidSigner(executor, "");
    }

    /**
     * @dev Updates account state based on previous state and msg.data
     */
    function _updateState() internal virtual {
        _state = uint256(keccak256(abi.encode(_state, _msgData())));
    }

    /**
     * @dev Called before executing an operation. Reverts if account is locked. Ensures state is
     * updated prior to execution.
     */
    function _beforeExecute() internal override {
        if (isLocked()) revert AccountLocked();
        _updateState();
    }

    function _getStorageOwner()
        internal
        view
        virtual
        override(Overridable, Permissioned)
        returns (address)
    {
        return owner();
    }

    function _canLockAccount() internal view virtual override returns (bool) {
        return _isValidSigner(_msgSender(), "");
    }

    function _beforeLock() internal override {
        if (isLocked()) revert AccountLocked();
        _updateState();
    }

    function _canSetOverrides() internal view virtual override returns (bool) {
        return _isValidSigner(_msgSender(), "");
    }

    function _beforeSetOverrides() internal override {
        if (isLocked()) revert AccountLocked();
        _updateState();
    }

    function _canSetPermissions() internal view virtual override returns (bool) {
        return _isValidSigner(_msgSender(), "");
    }

    function _beforeSetPermissions() internal override {
        if (isLocked()) revert AccountLocked();
        _updateState();
    }
}
