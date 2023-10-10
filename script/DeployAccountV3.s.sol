// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/AccountV3Upgradable.sol";
import "../src/AccountProxy.sol";

contract DeployAccountV3 is Script {
    function run() external {
        bytes32 salt = 0x6551655165516551655165516551655165516551655165516551655165516551;
        address erc4337EntryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        address multicallForwarder = 0x0000000000000000000000000000000000006551;
        address erc6551Registry = 0x0000000000000000000000000000000000006551;
        address accountGuardian = 0x026FAa5A8212B68b65C523DCBEb158Cd7a6Ae09C;

        vm.startBroadcast();
        AccountV3Upgradable implementation = new AccountV3Upgradable{
            salt: salt
        }(
            erc4337EntryPoint,
            multicallForwarder,
            erc6551Registry,
            accountGuardian
        );
        vm.stopBroadcast();

        vm.startBroadcast();
        new AccountProxy{
            salt: salt 
        }(accountGuardian, address(implementation));
        vm.stopBroadcast();
    }
}
