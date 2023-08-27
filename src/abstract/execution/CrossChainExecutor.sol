// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "erc6551/interfaces/IERC6551Executable.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/lib/ERC6551AccountLib.sol";

import "../../utils/Errors.sol";
import "../../lib/OPAddressAliasHelper.sol";
import "../../interfaces/IArbSys.sol";
import "./SandboxExecutor.sol";
import "./BaseExecutor.sol";

abstract contract CrossChainExecutor is BaseExecutor {
    function executeOptimism(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        returns (bytes memory)
    {
        if (OPAddressAliasHelper.undoL1ToL2Alias(_msgSender()) != address(this)) revert NotAuthorized();

        _beforeExecute();

        return LibExecutor._execute(to, value, data, operation);
    }

    function executeArbitrum(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        returns (bytes memory)
    {
        address arbSys = address(100);

        if (arbSys.code.length == 0) revert NotAuthorized();

        try IArbSys(arbSys).wasMyCallersAddressAliased() returns (bool aliased) {
            if (!aliased) revert NotAuthorized();
            if (IArbSys(arbSys).myCallersAddressWithoutAliasing() != _msgSender()) revert NotAuthorized();
        } catch {
            revert NotAuthorized();
        }

        _beforeExecute();

        return LibExecutor._execute(to, value, data, operation);
    }
}
