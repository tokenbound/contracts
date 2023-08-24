// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MulticallForwarder {
    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function forward(Call[] calldata calls) external returns (Result[] memory results) {
        uint256 length = calls.length;
        results = new Result[](length);
        Call calldata call;
        for (uint256 i = 0; i < length;) {
            Result memory result = results[i];
            call = calls[i];
            (result.success, result.returnData) = call.target.call(abi.encodePacked(call.callData, msg.sender));
            unchecked {
                ++i;
            }
        }
    }
}
