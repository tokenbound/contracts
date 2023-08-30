// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "erc6551/interfaces/IERC6551Executable.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/lib/ERC6551AccountLib.sol";

import "../../utils/Errors.sol";
import "../../lib/LibExecutor.sol";
import "../../lib/LibSandbox.sol";
import "./ERC6551Executor.sol";
import "./BatchExecutor.sol";
import "./NestedAccountExecutor.sol";

/**
 * @title Tokenbound Executor
 * @dev Enables basic ERC-6551 execution as well as batch, nested, and mult-account execution
 */
abstract contract TokenboundExecutor is
    ERC6551Executor,
    BatchExecutor,
    NestedAccountExecutor,
    ERC2771Context
{
    constructor(address multicallForwarder, address _erc6551Registry)
        ERC2771Context(multicallForwarder)
        NestedAccountExecutor(_erc6551Registry)
    {
        if (multicallForwarder == address(0)) revert InvalidMulticallForwarder();
    }

    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return super._msgData();
    }
}
