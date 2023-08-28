// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/utils/Create2.sol";

library LibSandbox {
    bytes public constant header = hex"604380600d600039806000f3fe73";
    bytes public constant footer =
        hex"3314601d573d3dfd5b363d3d373d3d6014360360143d5160601c5af43d6000803e80603e573d6000fd5b3d6000f3";

    function bytecode(address owner) internal pure returns (bytes memory) {
        return abi.encodePacked(header, owner, footer);
    }

    function sandbox(address owner) internal view returns (address) {
        return
            Create2.computeAddress(keccak256("org.tokenbound.sandbox"), keccak256(bytecode(owner)));
    }

    function deploy(address owner) internal {
        Create2.deploy(0, keccak256("org.tokenbound.sandbox"), bytecode(owner));
    }
}
