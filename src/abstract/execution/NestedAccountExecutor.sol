// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "erc6551/interfaces/IERC6551Executable.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/lib/ERC6551AccountLib.sol";

import "../../utils/Errors.sol";
import "../../lib/LibExecutor.sol";
import "../../lib/LibSandbox.sol";
import "./SandboxExecutor.sol";
import "./BaseExecutor.sol";

/**
 * @title Nested Account Executor
 * @notice Allows the root owner of a nested token bound account to execute transactions directly
 * against the nested account
 */
abstract contract NestedAccountExecutor is BaseExecutor {
    address private immutable __self = address(this);
    address public immutable erc6551Registry;

    struct ERC6551AccountInfo {
        address tokenContract;
        uint256 tokenId;
        uint256 salt;
    }

    constructor(address _erc6551Registry) {
        erc6551Registry = _erc6551Registry;
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
                erc6551Registry,
                __self,
                block.chainid,
                accountInfo.tokenContract,
                accountInfo.tokenId,
                accountInfo.salt
            );

            if (next.code.length == 0) revert InvalidAccountProof();
            if (
                IERC6551Account(payable(next)).isValidSigner(current, "")
                    != IERC6551Account.isValidSigner.selector
            ) {
                revert InvalidAccountProof();
            }

            current = next;
        }

        if (!_isValidExecutor(current)) revert NotAuthorized();

        _beforeExecute();

        return LibExecutor._execute(to, value, data, operation);
    }
}
