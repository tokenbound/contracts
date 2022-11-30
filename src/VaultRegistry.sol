// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/utils/Create2.sol";

import "./Vault.sol";

contract VaultRegistry {
    address public vaultBeacon;

    constructor(address _vaultBeacon) {
        vaultBeacon = _vaultBeacon;
    }

    function getVault(address tokenCollection, uint256 tokenId)
        public
        view
        returns (address payable)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        bytes memory creationCode = type(BeaconProxy).creationCode;
        bytes memory initializerCall = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            address(this),
            tokenCollection,
            tokenId
        );
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                creationCode,
                abi.encode(vaultBeacon, initializerCall)
            )
        );
        address predictedVaultAddress = Create2.computeAddress(
            salt,
            bytecodeHash
        );

        return payable(predictedVaultAddress);
    }

    function deployVault(address tokenCollection, uint256 tokenId)
        public
        returns (address payable)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        bytes memory initializerCall = abi.encodeWithSignature(
            "initialize(address,address,uint256)",
            address(this),
            tokenCollection,
            tokenId
        );
        address vaultAddress = address(
            new BeaconProxy{salt: salt}(vaultBeacon, initializerCall)
        );

        return payable(vaultAddress);
    }
}
