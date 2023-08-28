// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "erc6551/interfaces/IERC6551Executable.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/lib/ERC6551AccountLib.sol";

import "../../utils/Errors.sol";
import "../../lib/LibExecutor.sol";
import "../../lib/LibSandbox.sol";
import "./SandboxExecutor.sol";
import "./BaseExecutor.sol";

/**
 * @title ERC-6551 Executor
 * @notice Basic executor which implements the IERC6551Executable execution interface
 */
abstract contract ERC6551Executor is IERC6551Executable, ERC165, BaseExecutor {
    function execute(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        virtual
        returns (bytes memory)
    {
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();

        _beforeExecute();

        return LibExecutor._execute(to, value, data, operation);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC6551Executable).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
