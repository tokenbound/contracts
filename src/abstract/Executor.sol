// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "erc6551/interfaces/IERC6551Executable.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/lib/ERC6551AccountLib.sol";

import "../utils/Errors.sol";
import "../lib/LibExecutor.sol";
import "../lib/LibSandbox.sol";
import "./SandboxExecutor.sol";

abstract contract Executor is IERC6551Executable, ERC2771Context, SandboxExecutor {
    address private immutable __self = address(this);
    address public immutable erc6551Registry;

    struct ERC6551AccountInfo {
        address tokenContract;
        uint256 tokenId;
        uint256 salt;
    }

    struct Operation {
        address to;
        uint256 value;
        bytes data;
        uint256 operation;
    }

    uint256 constant OP_CALL = 0;
    uint256 constant OP_DELEGATECALL = 1;
    uint256 constant OP_CREATE = 2;
    uint256 constant OP_CREATE2 = 3;

    constructor(address multicallForwarder, address _erc6551Registry) ERC2771Context(multicallForwarder) {
        erc6551Registry = _erc6551Registry;
    }

    function execute(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        returns (bytes memory)
    {
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();

        _beforeExecute();

        return _execute(to, value, data, operation);
    }

    function executeBatch(Operation[] calldata operations) external payable returns (bytes[] memory) {
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();

        _beforeExecute();

        uint256 length = operations.length;
        bytes[] memory results = new bytes[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _execute(operations[i].to, operations[i].value, operations[i].data, operations[i].operation);
        }

        return results;
    }

    function executeNested(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 operation,
        ERC6551AccountInfo[] calldata proof
    ) external payable returns (bytes memory) {
        uint256 length = proof.length;
        address current = _msgSender();

        ERC6551AccountInfo calldata accountInfo;
        for (uint256 i = 0; i < length; i++) {
            accountInfo = proof[i];
            address next = ERC6551AccountLib.computeAddress(
                erc6551Registry, __self, block.chainid, accountInfo.tokenContract, accountInfo.tokenId, accountInfo.salt
            );

            if (next.code.length == 0) revert InvalidAccountProof();
            if (IERC6551Account(payable(next)).isValidSigner(current, "") != IERC6551Account.isValidSigner.selector) {
                revert InvalidAccountProof();
            }

            current = next;
        }

        if (!_isValidExecutor(current)) revert NotAuthorized();

        _beforeExecute();

        return _execute(to, value, data, operation);
    }

    function _execute(address to, uint256 value, bytes calldata data, uint256 operation)
        internal
        returns (bytes memory)
    {
        if (operation == OP_CALL) return LibExecutor._call(to, value, data);
        if (operation == OP_DELEGATECALL) {
            address sandbox = LibSandbox.sandbox(address(this));
            if (sandbox.code.length == 0) LibSandbox.deploy(address(this));
            return LibExecutor._call(sandbox, value, abi.encodePacked(to, data));
        }
        if (operation == OP_CREATE) return abi.encodePacked(LibExecutor._create(value, data));
        if (operation == OP_CREATE2) return abi.encodePacked(LibExecutor._create2(value, data));

        revert InvalidOperation();
    }

    function _beforeExecute() internal virtual {}

    function _isValidExecutor(address executor) internal view virtual returns (bool);
}
