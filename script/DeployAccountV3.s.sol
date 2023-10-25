// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/AccountGuardian.sol";
import "../src/AccountV3Upgradable.sol";
import "../src/AccountProxy.sol";

contract DeployAccountV3 is Script {
    function run() external {
        bytes32 salt = 0x6551655165516551655165516551655165516551655165516551655165516551;
        address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        address tokenboundSafe = 0x781b6A527482828bB04F33563797d4b696ddF328;
        address erc4337EntryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        address multicallForwarder = 0xcA1167915584462449EE5b4Ea51c37fE81eCDCCD;
        address erc6551Registry = 0x000000006551c19487814612e58FE06813775758;

        address guardian = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(type(AccountGuardian).creationCode, abi.encode(tokenboundSafe))
            ),
            factory
        );
        address implementation = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(AccountV3Upgradable).creationCode,
                    abi.encode(erc4337EntryPoint, multicallForwarder, erc6551Registry, guardian)
                )
            ),
            factory
        );
        address proxy = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(AccountProxy).creationCode, abi.encode(guardian, implementation)
                )
            ),
            factory
        );

        // Deploy AccountGuardian
        if (guardian.code.length == 0) {
            vm.startBroadcast();
            new AccountGuardian{salt: salt}(tokenboundSafe);
            vm.stopBroadcast();

            console.log("AccountGuardian:", guardian, "(deployed)");
        } else {
            console.log("AccountGuardian:", guardian, "(exists)");
        }

        // Deploy Account implementation
        if (implementation.code.length == 0) {
            vm.startBroadcast();
            new AccountV3Upgradable{salt: salt}(
                erc4337EntryPoint,
                multicallForwarder,
                erc6551Registry,
                guardian
            );
            vm.stopBroadcast();

            console.log("AccountV3Upgradable:", implementation, "(deployed)");
        } else {
            console.log("AccountV3Upgradable:", implementation, "(exists)");
        }

        // Deploy AccountProxy
        if (proxy.code.length == 0) {
            vm.startBroadcast();
            new AccountProxy{salt: salt}(guardian, implementation);
            vm.stopBroadcast();

            console.log("AccountProxy:", proxy, "(deployed)");
        } else {
            console.log("AccountProxy:", proxy, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "AccountGuardian: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            guardian,
            string.concat(
                "src/AccountGuardian.sol:AccountGuardian --constructor-args $(cast abi-encode \"constructor(address)\" ",
                Strings.toHexString(tokenboundSafe),
                ")\n"
            )
        );
        console.log(
            "AccountV3Upgradable: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            implementation,
            string.concat(
                "src/AccountV3Upgradable.sol:AccountV3Upgradable --constructor-args $(cast abi-encode \"constructor(address,address,address,address)\" ",
                Strings.toHexString(erc4337EntryPoint),
                " ",
                Strings.toHexString(multicallForwarder),
                " ",
                Strings.toHexString(erc6551Registry),
                " ",
                Strings.toHexString(guardian),
                ")\n"
            )
        );
        console.log(
            "AccountProxy: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            proxy,
            string.concat(
                "src/AccountProxy.sol:AccountProxy --constructor-args $(cast abi-encode \"constructor(address,address)\" ",
                Strings.toHexString(guardian),
                " ",
                Strings.toHexString(implementation),
                ")\n"
            )
        );
    }
}
