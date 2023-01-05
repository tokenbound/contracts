// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MinimalReceiver.sol";

contract LockedVault is MinimalReceiver {
    function executeCall(
        address payable to,
        uint256 value,
        bytes calldata data
    ) external payable {}

    function executeDelegateCall(address payable to, bytes calldata data)
        external
        payable
    {}

    function owner() external pure returns (address) {
        return address(0);
    }

    function isAuthorized(address) public pure virtual returns (bool) {
        return false;
    }

    function isValidSignature(bytes32, bytes memory)
        external
        pure
        returns (bytes4 magicValue)
    {
        return bytes4(0);
    }
}
