// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Delegate {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     *
     * Extracted from openzeppelin-contracts v4.6.0 (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/4e5b11919e91b18b6683b6f49a1b4fdede579969/contracts/proxy/Proxy.sol#L16-L45))
     */
    function delegate(address implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
