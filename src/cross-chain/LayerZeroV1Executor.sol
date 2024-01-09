// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ILayerZeroV1Receiver {
    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external;
}

contract LayerZeroV1Executor is ILayerZeroV1Receiver {
    address public immutable endpoint;

    event Executed(bool success, bytes data);

    error InvalidSender();

    constructor(address _endpoint) {
        endpoint = _endpoint;
    }

    function lzReceive(uint16, bytes calldata _srcAddress, uint64, bytes calldata _payload)
        external
        override
    {
        if (msg.sender != endpoint) revert InvalidSender();

        address src = address(uint160(bytes20(_srcAddress[:20])));

        (bool success, bytes memory result) = src.call(_payload);
        emit Executed(success, result);
    }
}
