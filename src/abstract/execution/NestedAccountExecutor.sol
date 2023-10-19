// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "erc6551/interfaces/IERC6551Executable.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/lib/ERC6551AccountLib.sol";

import "../../utils/Errors.sol";
import "../../lib/LibExecutor.sol";
import "../../lib/LibSandbox.sol";
import "./SandboxExecutor.sol";
import "./BaseExecutor.sol";

import "../Lockable.sol";

/**
 * @title Nested Account Executor
 * @dev Allows the root owner of a nested token bound account to execute transactions directly
 * against the nested account, even if intermediate accounts have not been created.
 */
abstract contract NestedAccountExecutor is BaseExecutor {
    address immutable __self = address(this);
    address public immutable erc6551Registry;

    struct ERC6551AccountInfo {
        bytes32 salt;
        address tokenContract;
        uint256 tokenId;
    }

    constructor(address _erc6551Registry) {
        if (_erc6551Registry == address(0)) revert InvalidERC6551Registry();
        erc6551Registry = _erc6551Registry;
    }

    /**
     * Executes a low-level operation from this account if the caller is a valid signer on the
     * parent TBA specified in the proof
     *
     * @param to Account to operate on
     * @param value Value to send with operation
     * @param data Encoded calldata of operation
     * @param operation Operation type (0=CALL, 1=DELEGATECALL, 2=CREATE, 3=CREATE2)
     * @param proof An array of ERC-6551 account information specifying the ownership path from this
     * account to its parent
     */
    function executeNested(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        ERC6551AccountInfo[] calldata proof
    ) external payable returns (bytes memory) {
        uint256 length = proof.length;
        address current = _msgSender();

        ERC6551AccountInfo calldata accountInfo;
        for (uint256 i = 0; i < length; i++) {
            accountInfo = proof[i];
            address tokenContract = accountInfo.tokenContract;
            uint256 tokenId = accountInfo.tokenId;

            address next = ERC6551AccountLib.computeAddress(
                erc6551Registry, __self, accountInfo.salt, block.chainid, tokenContract, tokenId
            );

            if (tokenContract.code.length == 0) revert InvalidAccountProof();

            if (next.code.length > 0) {
                if (Lockable(next).isLocked()) revert AccountLocked();
            }

            try IERC721(tokenContract).ownerOf(tokenId) returns (address _owner) {
                if (_owner != current) revert InvalidAccountProof();
                current = next;
            } catch {
                revert InvalidAccountProof();
            }
        }

        if (!_isValidExecutor(current)) revert NotAuthorized();

        _beforeExecute();

        return LibExecutor._execute(to, value, data, operation);
    }
}
