// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title Multicall Forwarder
 * @notice Allows operations on multiple token bound accounts to be executed at once
 */
contract MulticallForwarder {
    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    /**
     * @notice Executes multiple encoded calls with msg.sender appended to the calldata in the
     * style of ERC-2771
     *
     * @dev To enable multi-account execution, this contract should be set as a trusted forwarder
     * on the account
     *
     * @param calls An array of encoded smart contract calls
     */
    function forward(Call[] calldata calls) external returns (Result[] memory results) {
        uint256 length = calls.length;
        results = new Result[](length);
        Call calldata call;
        for (uint256 i = 0; i < length;) {
            Result memory result = results[i];
            call = calls[i];
            (result.success, result.returnData) =
                call.target.call(abi.encodePacked(call.callData, msg.sender));
            unchecked {
                ++i;
            }
        }
    }
}
