// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/interfaces/IERC6551Executable.sol";
import "erc6551/lib/ERC6551AccountLib.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "./abstract/ExecutableAccount.sol";
import "./abstract/SigningAccount.sol";
import "./abstract/ERC4337Account.sol";

contract ExternalStorage {
    function store(bytes32 slot, bytes32 value) external {
        bytes32 scopedSlot = keccak256(abi.encode(msg.sender, slot));
        assembly {
            sstore(scopedSlot, value)
        }
    }

    function load(address scope, bytes32 slot) external view returns (bytes32 value) {
        bytes32 scopedSlot = keccak256(abi.encode(scope, slot));
        assembly {
            value := sload(scopedSlot)
        }
    }

    function lock() external {}
    function locked() public view returns (bool) {}
}

contract AccountV3 is IERC6551Account, SigningAccount, ExecutableAccount, ERC4337Account {
    ExternalStorage public immutable _storage;

    constructor(address _entryPoint, address externalStorage) ERC4337Account(_entryPoint) {
        _storage = ExternalStorage(externalStorage);
    }

    receive() external payable {}

    fallback() external payable {}

    function state() external view returns (uint256) {
        bytes32 stateKey = keccak256("org.tokenbound.state");
        bytes32 _state = _storage.load(address(this), stateKey);
        return uint256(_state);
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

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();

        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function _isValidSigner(address signer, bytes memory) internal view virtual returns (bool) {
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
        return _isValidSigner(executor, "");
    }

    function _beforeExecute(address to, uint256 value, bytes calldata data, uint256 operation)
        internal
        virtual
        override
    {
        bytes32 stateKey = keccak256("org.tokenbound.state");
        bytes32 currentState = _storage.load(address(this), stateKey);
        bytes32 executionHash = keccak256(abi.encode(to, value, data, operation));
        _storage.store(stateKey, keccak256(abi.encode(currentState, executionHash)));
    }
}
