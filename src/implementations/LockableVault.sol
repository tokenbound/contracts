// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/proxy/Proxy.sol";
import "../Vault.sol";
import "../interfaces/IVault.sol";

contract LockModule {
    mapping(address => mapping(address => uint256)) unlockTimestamp;

    function isLocked(address vault, address owner) public view returns (bool) {
        return unlockTimestamp[vault][owner] > block.timestamp;
    }

    function setUnlockTimestamp(address payable vault, uint256 _unlockTimestamp)
        public
    {
        IVault vaultInstance = IVault(vault);
        address _owner = vaultInstance.owner();
        bool isAuthorized = vaultInstance.isAuthorized(msg.sender);

        if (!isLocked(vault, _owner) && isAuthorized) {
            unlockTimestamp[vault][_owner] = _unlockTimestamp;
        }
    }
}

contract LockableVault is Vault {
    LockModule public immutable lockModule;

    constructor(address _registry, address _lockModule) Vault(_registry) {
        lockModule = LockModule(_lockModule);
    }

    function isAuthorized(address caller) public view override returns (bool) {
        return owner() == caller && !lockModule.isLocked(address(this), caller);
    }
}
