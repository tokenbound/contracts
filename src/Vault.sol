// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "delegation-registry/IDelegationRegistry.sol";

import "./VaultRegistry.sol";

error AlreadyInitialized();

contract Vault is Initializable {
    // before any transfer
    // check nft ownership
    // extensible as fuck

    address public constant delegationRegistry =
        0x00000000000076A84feF008CDAbe6409d2FE638B;

    address vaultRegistry;
    address tokenCollection;
    uint256 tokenId;

    mapping(address => uint256) unlockTimestamp;

    function initialize(
        address _vaultRegistry,
        address _tokenCollection,
        uint256 _tokenId
    ) public initializer {
        vaultRegistry = _vaultRegistry;
        require(
            address(this) ==
                VaultRegistry(vaultRegistry).getVault(
                    _tokenCollection,
                    _tokenId
                ),
            "Not vault"
        );
        tokenCollection = _tokenCollection;
        tokenId = _tokenId;
    }

    modifier onlyOwnerOrDelegate() {
        address owner = IERC721(tokenCollection).ownerOf(tokenId);
        require(
            msg.sender == owner ||
                IDelegationRegistry(delegationRegistry).checkDelegateForToken(
                    msg.sender,
                    owner,
                    tokenCollection,
                    tokenId
                ),
            "Not owner"
        );
        _;
    }

    modifier onlyVault() {
        require(
            address(this) ==
                VaultRegistry(vaultRegistry).getVault(tokenCollection, tokenId),
            "Not vault"
        );
        _;
    }

    function lock(uint256 _unlockTimestamp)
        public
        payable
        onlyVault
        onlyOwnerOrDelegate
    {
        unlockTimestamp[
            IERC721(tokenCollection).ownerOf(tokenId)
        ] = _unlockTimestamp;
    }

    function execTransaction(
        address payable to,
        uint256 value,
        bytes calldata data
    ) public payable onlyVault onlyOwnerOrDelegate {
        address owner = IERC721(tokenCollection).ownerOf(tokenId);
        require(unlockTimestamp[owner] < block.timestamp, "Vault is locked");

        (bool success, bytes memory result) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function isValidDelegateSignatureNow(
        address[] memory delegates,
        bytes32 _hash,
        bytes memory _signature
    ) public view onlyVault returns (bool) {
        for (uint256 i = 0; i < delegates.length; i++) {
            if (
                SignatureChecker.isValidSignatureNow(
                    delegates[i],
                    _hash,
                    _signature
                )
            ) {
                return true;
            }
        }

        return false;
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature)
        public
        view
        onlyVault
        returns (bytes4 magicValue)
    {
        address owner = IERC721(tokenCollection).ownerOf(tokenId);

        bool isValid = SignatureChecker.isValidSignatureNow(
            owner,
            _hash,
            _signature
        );

        if (isValid && unlockTimestamp[owner] < block.timestamp) {
            return IERC1271.isValidSignature.selector;
        }

        // check token-level delegations
        address[] memory tokenDelegates = IDelegationRegistry(
            delegationRegistry
        ).getDelegatesForToken(owner, tokenCollection, tokenId);

        if (isValidDelegateSignatureNow(tokenDelegates, _hash, _signature)) {
            return IERC1271.isValidSignature.selector;
        }

        // check contract-level delegations
        address[] memory contractDelegates = IDelegationRegistry(
            delegationRegistry
        ).getDelegatesForContract(owner, tokenCollection);
        if (isValidDelegateSignatureNow(contractDelegates, _hash, _signature)) {
            return IERC1271.isValidSignature.selector;
        }

        // check global delegations
        address[] memory globalDelegates = IDelegationRegistry(
            delegationRegistry
        ).getDelegatesForAll(owner);
        if (isValidDelegateSignatureNow(globalDelegates, _hash, _signature)) {
            return IERC1271.isValidSignature.selector;
        }
    }

    // receiver functions

    receive() external payable {}

    fallback() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
