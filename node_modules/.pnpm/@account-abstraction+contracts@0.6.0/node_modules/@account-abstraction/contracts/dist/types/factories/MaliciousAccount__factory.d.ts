import { Signer, ContractFactory, PayableOverrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type { MaliciousAccount, MaliciousAccountInterface } from "../MaliciousAccount";
type MaliciousAccountConstructorParams = [signer?: Signer] | ConstructorParameters<typeof ContractFactory>;
export declare class MaliciousAccount__factory extends ContractFactory {
    constructor(...args: MaliciousAccountConstructorParams);
    deploy(_ep: PromiseOrValue<string>, overrides?: PayableOverrides & {
        from?: PromiseOrValue<string>;
    }): Promise<MaliciousAccount>;
    getDeployTransaction(_ep: PromiseOrValue<string>, overrides?: PayableOverrides & {
        from?: PromiseOrValue<string>;
    }): TransactionRequest;
    attach(address: string): MaliciousAccount;
    connect(signer: Signer): MaliciousAccount__factory;
    static readonly bytecode = "0x60806040526040516103ec3803806103ec83398101604081905261002291610047565b600080546001600160a01b0319166001600160a01b0392909216919091179055610077565b60006020828403121561005957600080fd5b81516001600160a01b038116811461007057600080fd5b9392505050565b610366806100866000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c80633a871cdd14610030575b600080fd5b61004361003e3660046101be565b610055565b60405190815260200160405180910390f35b600080546040517fb760faf900000000000000000000000000000000000000000000000000000000815230600482015273ffffffffffffffffffffffffffffffffffffffff9091169063b760faf99084906024016000604051808303818588803b1580156100c257600080fd5b505af11580156100d6573d6000803e3d6000fd5b50505050506000848061014001906100ee9190610212565b8101906100fb919061027e565b9050600060c086013561011660a088013560808901356102c6565b61012091906102c6565b9050600061012e82866102de565b9050600061014161010089013583610319565b90508381146101b0576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f5265766572742061667465722066697273742076616c69646174696f6e000000604482015260640160405180910390fd5b506000979650505050505050565b6000806000606084860312156101d357600080fd5b833567ffffffffffffffff8111156101ea57600080fd5b840161016081870312156101fd57600080fd5b95602085013595506040909401359392505050565b60008083357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe184360301811261024757600080fd5b83018035915067ffffffffffffffff82111561026257600080fd5b60200191503681900382131561027757600080fd5b9250929050565b60006020828403121561029057600080fd5b5035919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b600082198211156102d9576102d9610297565b500190565b600082610314577f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b500490565b60008282101561032b5761032b610297565b50039056fea26469706673582212207a8e78673a414e5633ca0da4ad76d63f65bd0d2c09da97ae1b26e837ad5870da64736f6c634300080f0033";
    static readonly abi: readonly [{
        readonly inputs: readonly [{
            readonly internalType: "contract IEntryPoint";
            readonly name: "_ep";
            readonly type: "address";
        }];
        readonly stateMutability: "payable";
        readonly type: "constructor";
    }, {
        readonly inputs: readonly [{
            readonly components: readonly [{
                readonly internalType: "address";
                readonly name: "sender";
                readonly type: "address";
            }, {
                readonly internalType: "uint256";
                readonly name: "nonce";
                readonly type: "uint256";
            }, {
                readonly internalType: "bytes";
                readonly name: "initCode";
                readonly type: "bytes";
            }, {
                readonly internalType: "bytes";
                readonly name: "callData";
                readonly type: "bytes";
            }, {
                readonly internalType: "uint256";
                readonly name: "callGasLimit";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "verificationGasLimit";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "preVerificationGas";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "maxFeePerGas";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "maxPriorityFeePerGas";
                readonly type: "uint256";
            }, {
                readonly internalType: "bytes";
                readonly name: "paymasterAndData";
                readonly type: "bytes";
            }, {
                readonly internalType: "bytes";
                readonly name: "signature";
                readonly type: "bytes";
            }];
            readonly internalType: "struct UserOperation";
            readonly name: "userOp";
            readonly type: "tuple";
        }, {
            readonly internalType: "bytes32";
            readonly name: "";
            readonly type: "bytes32";
        }, {
            readonly internalType: "uint256";
            readonly name: "missingAccountFunds";
            readonly type: "uint256";
        }];
        readonly name: "validateUserOp";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "validationData";
            readonly type: "uint256";
        }];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }];
    static createInterface(): MaliciousAccountInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): MaliciousAccount;
}
export {};
