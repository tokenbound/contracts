// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Origin} from "layerzero-v2/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract LayerZeroV2Executor {
    uint64 internal constant RECEIVER_VERSION = 1;
    address public immutable endpoint;

    error InvalidSender();

    constructor(address _endpoint) {
        endpoint = _endpoint;
    }

    function oAppVersion()
        public
        view
        virtual
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        return (0, RECEIVER_VERSION);
    }

    function nextNonce(uint32, /*_srcEid*/ bytes32 /*_sender*/ )
        public
        view
        virtual
        returns (uint64 nonce)
    {
        return 0;
    }

    function allowInitializePath(Origin calldata) public view virtual returns (bool) {
        return true;
    }

    function lzReceive(
        Origin calldata _origin,
        bytes32, // _guid
        bytes calldata _message,
        address, // _executor
        bytes calldata // _extraData
    ) external payable {
        if (msg.sender != endpoint) revert InvalidSender();

        address src = address(uint160(uint256(_origin.sender)));

        (bool success, bytes memory result) = src.call(_message);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
