// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/AccountGuardian.sol";

contract DeployGuardian is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("GUARDIAN_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        new AccountGuardian();

        vm.stopBroadcast();
    }
}
