// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";

import "./Vault.sol";

/// @title VaultRegistry
/// @notice Determines the address for each tokenbound Vault and performs deployment of Vault instances
/// @author Jayden Windle
contract VaultRegistry {
    address public vaultImplementation;

    struct VaultData {
        address tokenCollection;
        uint256 tokenId;
    }

    /// @dev mapping from vault address to VaultData
    mapping(address => VaultData) public vaultData;

    /// @dev mapping from vault owner address to unlock timestamp
    mapping(address => uint256) public unlockTimestamp;

    /// @dev deploys the canonical vault implementation
    constructor() {
        vaultImplementation = address(new Vault());
    }

    /**
     * @dev Deploys the Vault instance for an ERC721 token.
     * @return The address of the deployed Vault
     */
    function deployVault(address tokenCollection, uint256 tokenId)
        public
        returns (address payable)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        address vaultClone = Clones.cloneDeterministic(
            vaultImplementation,
            salt
        );

        vaultData[vaultClone] = VaultData(tokenCollection, tokenId);

        return payable(vaultClone);
    }

    /**
     * @dev Gets the address of the Vault for an ERC721 token. If Vault is not deployed,
     * the return value is the address that the Vault will eventually be deployed to
     * @return The Vault address
     */
    function vaultAddress(address tokenCollection, uint256 tokenId)
        public
        view
        returns (address payable)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenCollection, tokenId));
        address vaultClone = Clones.predictDeterministicAddress(
            vaultImplementation,
            salt
        );
        return payable(vaultClone);
    }

    /// @dev Returns the owner of the Vault, which is the owner of the underlying ERC721 token
    function vaultOwner(address vault) public view returns (address) {
        VaultData memory data = vaultData[vault];

        if (data.tokenCollection == address(0)) {
            return address(0);
        }

        return IERC721(data.tokenCollection).ownerOf(data.tokenId);
    }

    /// @dev Returns true if caller is authorized to call vault, false otherwise
    function isAuthorizedCaller(address vault, address caller)
        external
        view
        returns (bool)
    {
        return vaultOwner(vault) == caller && !isLocked(vault);
    }

    /**
     * @dev Disables all actions on the Vault until a certain time. Vault is
     * automatically unlocked when ownership token is transferred
     * @param _unlockTimestamp Timestamp at which the vault will be unlocked
     */
    function lockVault(uint256 _unlockTimestamp) external {
        address _owner = vaultOwner(msg.sender);
        if (unlockTimestamp[_owner] < block.timestamp) {
            unlockTimestamp[_owner] = _unlockTimestamp;
        }
    }

    /// @dev returns true if vault is locked, false otherwise
    function isLocked(address vault) public view returns (bool) {
        address _owner = vaultOwner(vault);
        return unlockTimestamp[_owner] > block.timestamp;
    }
}
