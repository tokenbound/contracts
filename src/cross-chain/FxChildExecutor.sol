// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IFxMessageProcessor {
    function processMessageFromRoot(uint256 stateId, address rootMessageSender, bytes calldata data)
        external;
}

contract FxChildExecutor is IFxMessageProcessor {
    address public immutable fxChild;

    event Executed(bool success, bytes data);

    error InvalidSender();

    constructor(address _fxChild) {
        fxChild = _fxChild;
    }

    function processMessageFromRoot(uint256, address rootMessageSender, bytes calldata data)
        external
    {
        if (msg.sender != fxChild) revert InvalidSender();
        (bool success, bytes memory result) = rootMessageSender.call(data);
        emit Executed(success, result);
    }
}
