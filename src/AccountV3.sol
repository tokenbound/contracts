// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "erc6551/lib/ERC6551AccountLib.sol";

import "./abstract/Lockable.sol";
import "./abstract/Overridable.sol";
import "./abstract/Permissioned.sol";
import "./abstract/ERC6551Account.sol";
import "./abstract/ERC4337Account.sol";
import "./abstract/execution/TokenboundExecutor.sol";

import "./lib/OPAddressAliasHelper.sol";

import "./interfaces/IAccountGuardian.sol";

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
    IAccountGuardian immutable guardian;

    /**
     * @param entryPoint_ The ERC-4337 EntryPoint address
     * @param multicallForwarder The MulticallForwarder address
     * @param erc6551Registry The ERC-6551 Registry address
     * @param _guardian The AccountGuardian address
     */
    constructor(
        address entryPoint_,
        address multicallForwarder,
        address erc6551Registry,
        address _guardian
    ) ERC4337Account(entryPoint_) TokenboundExecutor(multicallForwarder, erc6551Registry) {
        guardian = IAccountGuardian(_guardian);
    }

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
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        return _tokenOwner(chainId, tokenContract, tokenId);
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
     * @dev called whenever an ERC-721 token is received. Can be overriden via Overridable. Reverts
     * if token being received is the token the account is bound to.
     */
    function onERC721Received(address, address, uint256 tokenId, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        (uint256 chainId, address tokenContract, uint256 _tokenId) = ERC6551AccountLib.token();

        if (msg.sender == tokenContract && tokenId == _tokenId && chainId == block.chainid) {
            revert OwnershipCycle();
        }

        _handleOverride();

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
        _handleOverride();
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
        _handleOverride();
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
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();

        // Single level accuont owner is valid signer
        address _owner = _tokenOwner(chainId, tokenContract, tokenId);
        if (signer == _owner) return true;

        // Root owner of accuont tree is valid signer
        address _rootOwner = _rootTokenOwner(_owner, chainId, tokenContract, tokenId);
        if (signer == _rootOwner) return true;

        // Accounts granted permission by root owner are valid signers
        return hasPermission(signer, _rootOwner);
    }

    /**
     * Determines if a given hash and signature are valid for this account
     * @param hash Hash of signed data
     * @param signature ECDSA signature or encoded contract signature (v=0)
     */
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
            if (!_isValidSigner(signer, "") && signer != address(this)) {
                return false;
            }

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

        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();

        // Allow cross chain execution
        if (chainId != block.chainid) {
            // Allow execution from L1 account on OPStack chains
            if (OPAddressAliasHelper.undoL1ToL2Alias(_msgSender()) == address(this)) {
                return true;
            }

            // Allow execution from trusted cross chain bridges
            if (guardian.isTrustedExecutor(executor)) return true;
        }

        // Allow execution from owner
        address _owner = _tokenOwner(chainId, tokenContract, tokenId);
        if (executor == _owner) return true;

        // Allow execution from root owner of account tree
        address _rootOwner = _rootTokenOwner(_owner, chainId, tokenContract, tokenId);
        if (executor == _rootOwner) return true;

        // Allow execution from permissioned account
        if (hasPermission(executor, _rootOwner)) return true;

        return false;
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

    /**
     * @dev Called before locking the account. Reverts if account is locked. Updates account state.
     */
    function _beforeLock() internal override {
        if (isLocked()) revert AccountLocked();
        _updateState();
    }

    /**
     * @dev Called before setting overrides on the account. Reverts if account is locked. Updates
     * account state.
     */
    function _beforeSetOverrides() internal override {
        if (isLocked()) revert AccountLocked();
        _updateState();
    }

    /**
     * @dev Called before setting permissions on the account. Reverts if account is locked. Updates
     * account state.
     */
    function _beforeSetPermissions() internal override {
        if (isLocked()) revert AccountLocked();
        _updateState();
    }

    /**
     * @dev Returns the root owner of an account. If account is not owned by a TBA, returns the
     * owner of the NFT bound to this account. If account is owned by a TBA, iterates up token
     * ownership tree and returns root owner.
     *
     * *Security Warning*: the return value of this function can only be trusted if it is also the
     * address of the sender (as the code of the NFT contract cannot be trusted). This function
     * should therefore only be used for authorization and never authentication.
     */
    function _rootTokenOwner(uint256 chainId, address tokenContract, uint256 tokenId)
        internal
        view
        virtual
        override(Overridable, Permissioned, Lockable)
        returns (address)
    {
        address _owner = _tokenOwner(chainId, tokenContract, tokenId);

        return _rootTokenOwner(_owner, chainId, tokenContract, tokenId);
    }

    /**
     * @dev Returns the root owner of an account given a known account owner address (saves an
     * additional external call).
     */
    function _rootTokenOwner(
        address owner_,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal view virtual returns (address) {
        address _owner = owner_;

        while (ERC6551AccountLib.isERC6551Account(_owner, __self, erc6551Registry)) {
            (chainId, tokenContract, tokenId) = IERC6551Account(payable(_owner)).token();
            _owner = _tokenOwner(chainId, tokenContract, tokenId);
        }

        return _owner;
    }

    /**
     * @dev Returns the owner of the token which this account is bound to. Returns the zero address
     * if token does not exist on the current chain or if the token contract does not exist
     */
    function _tokenOwner(uint256 chainId, address tokenContract, uint256 tokenId)
        internal
        view
        virtual
        returns (address)
    {
        if (chainId != block.chainid) return address(0);
        if (tokenContract.code.length == 0) return address(0);

        try IERC721(tokenContract).ownerOf(tokenId) returns (address _owner) {
            return _owner;
        } catch {
            return address(0);
        }
    }
}
