import { Signer, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type { VerifyingPaymaster, VerifyingPaymasterInterface } from "../VerifyingPaymaster";
type VerifyingPaymasterConstructorParams = [signer?: Signer] | ConstructorParameters<typeof ContractFactory>;
export declare class VerifyingPaymaster__factory extends ContractFactory {
    constructor(...args: VerifyingPaymasterConstructorParams);
    deploy(_entryPoint: PromiseOrValue<string>, _verifyingSigner: PromiseOrValue<string>, overrides?: Overrides & {
        from?: PromiseOrValue<string>;
    }): Promise<VerifyingPaymaster>;
    getDeployTransaction(_entryPoint: PromiseOrValue<string>, _verifyingSigner: PromiseOrValue<string>, overrides?: Overrides & {
        from?: PromiseOrValue<string>;
    }): TransactionRequest;
    attach(address: string): VerifyingPaymaster;
    connect(signer: Signer): VerifyingPaymaster__factory;
    static readonly bytecode = "0x60c06040523480156200001157600080fd5b5060405162001723380380620017238339810160408190526200003491620000c2565b81620000403362000059565b6001600160a01b039081166080521660a0525062000101565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6001600160a01b0381168114620000bf57600080fd5b50565b60008060408385031215620000d657600080fd5b8251620000e381620000a9565b6020840151909250620000f681620000a9565b809150509250929050565b60805160a0516115c46200015f6000396000818161013f0152610ca20152600081816102880152818161038601528181610450015281816105730152818161063a015281816106ca0152818161077d0152610a0401526115c46000f3fe6080604052600436106100f35760003560e01c8063a9a234091161008a578063c399ec8811610059578063c399ec88146102df578063d0e30db0146102f4578063f2fde38b146102fc578063f465c77e1461031c57600080fd5b8063a9a2340914610256578063b0d691fe14610276578063bb9fe6bf146102aa578063c23a5cea146102bf57600080fd5b80638da5cb5b116100c65780638da5cb5b146101a057806394d4ad60146101cb57806394e1fc19146101fb5780639c90b4431461022957600080fd5b80630396cb60146100f8578063205c28781461010d57806323d9ac9b1461012d578063715018a61461018b575b600080fd5b61010b610106366004611075565b61034a565b005b34801561011957600080fd5b5061010b6101283660046110c4565b6103fc565b34801561013957600080fd5b506101617f000000000000000000000000000000000000000000000000000000000000000081565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020015b60405180910390f35b34801561019757600080fd5b5061010b610494565b3480156101ac57600080fd5b5060005473ffffffffffffffffffffffffffffffffffffffff16610161565b3480156101d757600080fd5b506101eb6101e6366004611132565b6104a8565b6040516101829493929190611174565b34801561020757600080fd5b5061021b610216366004611212565b6104e5565b604051908152602001610182565b34801561023557600080fd5b5061021b610244366004611270565b60016020526000908152604090205481565b34801561026257600080fd5b5061010b61027136600461128d565b61054f565b34801561028257600080fd5b506101617f000000000000000000000000000000000000000000000000000000000000000081565b3480156102b657600080fd5b5061010b610569565b3480156102cb57600080fd5b5061010b6102da366004611270565b6105ed565b3480156102eb57600080fd5b5061021b610699565b61010b61074f565b34801561030857600080fd5b5061010b610317366004611270565b6107d7565b34801561032857600080fd5b5061033c6103373660046112ed565b610893565b6040516101829291906113a6565b6103526108b7565b6040517f0396cb6000000000000000000000000000000000000000000000000000000000815263ffffffff821660048201527f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1690630396cb609034906024016000604051808303818588803b1580156103e057600080fd5b505af11580156103f4573d6000803e3d6000fd5b505050505050565b6104046108b7565b6040517f205c287800000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff8381166004830152602482018390527f0000000000000000000000000000000000000000000000000000000000000000169063205c287890604401600060405180830381600087803b1580156103e057600080fd5b61049c6108b7565b6104a66000610938565b565b60008036816104bb6054601487896113c8565b8101906104c891906113f2565b90945092506104da85605481896113c8565b949793965094505050565b60006104f0846109ad565b73ffffffffffffffffffffffffffffffffffffffff8535166000908152600160209081526040918290205491516105309392469230928991899101611425565b6040516020818303038152906040528051906020012090509392505050565b6105576109ec565b61056384848484610a8b565b50505050565b6105716108b7565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663bb9fe6bf6040518163ffffffff1660e01b8152600401600060405180830381600087803b1580156105d957600080fd5b505af1158015610563573d6000803e3d6000fd5b6105f56108b7565b6040517fc23a5cea00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff82811660048301527f0000000000000000000000000000000000000000000000000000000000000000169063c23a5cea90602401600060405180830381600087803b15801561067e57600080fd5b505af1158015610692573d6000803e3d6000fd5b5050505050565b6040517f70a082310000000000000000000000000000000000000000000000000000000081523060048201526000907f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16906370a0823190602401602060405180830381865afa158015610726573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061074a9190611482565b905090565b6040517fb760faf90000000000000000000000000000000000000000000000000000000081523060048201527f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff169063b760faf99034906024016000604051808303818588803b15801561067e57600080fd5b6107df6108b7565b73ffffffffffffffffffffffffffffffffffffffff8116610887576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201527f646472657373000000000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b61089081610938565b50565b6060600061089f6109ec565b6108aa858585610aed565b915091505b935093915050565b60005473ffffffffffffffffffffffffffffffffffffffff1633146104a6576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161087e565b6000805473ffffffffffffffffffffffffffffffffffffffff8381167fffffffffffffffffffffffff0000000000000000000000000000000000000000831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b60603660006109c061012085018561149b565b915091508360208184030360405194506020810185016040528085528082602087013750505050919050565b3373ffffffffffffffffffffffffffffffffffffffff7f000000000000000000000000000000000000000000000000000000000000000016146104a6576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601560248201527f53656e646572206e6f7420456e747279506f696e740000000000000000000000604482015260640161087e565b6040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152600d60248201527f6d757374206f7665727269646500000000000000000000000000000000000000604482015260640161087e565b6060600080803681610b066101e66101208b018b61149b565b929650909450925090506040811480610b1f5750604181145b610bad57604080517f08c379a00000000000000000000000000000000000000000000000000000000081526020600482015260248101919091527f566572696679696e675061796d61737465723a20696e76616c6964207369676e60448201527f6174757265206c656e67746820696e207061796d6173746572416e6444617461606482015260840161087e565b6000610c10610bbd8b87876104e5565b6040517f19457468657265756d205369676e6564204d6573736167653a0a3332000000006020820152603c8101829052600090605c01604051602081830303815290604052805190602001209050919050565b73ffffffffffffffffffffffffffffffffffffffff8b35166000908152600160205260408120805492935090610c4583611500565b9190505550610c8a8184848080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250610d3292505050565b73ffffffffffffffffffffffffffffffffffffffff167f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1614610d0757610ce860018686610d56565b60405180602001604052806000815250909650965050505050506108af565b610d1360008686610d56565b6040805160208101909152600081529b909a5098505050505050505050565b6000806000610d418585610d8e565b91509150610d4e81610dd3565b509392505050565b600060d08265ffffffffffff16901b60a08465ffffffffffff16901b85610d7e576000610d81565b60015b60ff161717949350505050565b6000808251604103610dc45760208301516040840151606085015160001a610db887828585610f86565b94509450505050610dcc565b506000905060025b9250929050565b6000816004811115610de757610de761155f565b03610def5750565b6001816004811115610e0357610e0361155f565b03610e6a576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601860248201527f45434453413a20696e76616c6964207369676e61747572650000000000000000604482015260640161087e565b6002816004811115610e7e57610e7e61155f565b03610ee5576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601f60248201527f45434453413a20696e76616c6964207369676e6174757265206c656e67746800604482015260640161087e565b6003816004811115610ef957610ef961155f565b03610890576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602260248201527f45434453413a20696e76616c6964207369676e6174757265202773272076616c60448201527f7565000000000000000000000000000000000000000000000000000000000000606482015260840161087e565b6000807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115610fbd575060009050600361106c565b6040805160008082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015611011573d6000803e3d6000fd5b50506040517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0015191505073ffffffffffffffffffffffffffffffffffffffff81166110655760006001925092505061106c565b9150600090505b94509492505050565b60006020828403121561108757600080fd5b813563ffffffff8116811461109b57600080fd5b9392505050565b73ffffffffffffffffffffffffffffffffffffffff8116811461089057600080fd5b600080604083850312156110d757600080fd5b82356110e2816110a2565b946020939093013593505050565b60008083601f84011261110257600080fd5b50813567ffffffffffffffff81111561111a57600080fd5b602083019150836020828501011115610dcc57600080fd5b6000806020838503121561114557600080fd5b823567ffffffffffffffff81111561115c57600080fd5b611168858286016110f0565b90969095509350505050565b600065ffffffffffff8087168352808616602084015250606060408301528260608301528284608084013760006080848401015260807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f850116830101905095945050505050565b600061016082840312156111f157600080fd5b50919050565b803565ffffffffffff8116811461120d57600080fd5b919050565b60008060006060848603121561122757600080fd5b833567ffffffffffffffff81111561123e57600080fd5b61124a868287016111de565b935050611259602085016111f7565b9150611267604085016111f7565b90509250925092565b60006020828403121561128257600080fd5b813561109b816110a2565b600080600080606085870312156112a357600080fd5b8435600381106112b257600080fd5b9350602085013567ffffffffffffffff8111156112ce57600080fd5b6112da878288016110f0565b9598909750949560400135949350505050565b60008060006060848603121561130257600080fd5b833567ffffffffffffffff81111561131957600080fd5b611325868287016111de565b9660208601359650604090950135949350505050565b6000815180845260005b8181101561136157602081850181015186830182015201611345565b81811115611373576000602083870101525b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0169290920160200192915050565b6040815260006113b9604083018561133b565b90508260208301529392505050565b600080858511156113d857600080fd5b838611156113e557600080fd5b5050820193919092039150565b6000806040838503121561140557600080fd5b61140e836111f7565b915061141c602084016111f7565b90509250929050565b60c08152600061143860c083018961133b565b60208301979097525073ffffffffffffffffffffffffffffffffffffffff949094166040850152606084019290925265ffffffffffff90811660808401521660a090910152919050565b60006020828403121561149457600080fd5b5051919050565b60008083357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe18436030181126114d057600080fd5b83018035915067ffffffffffffffff8211156114eb57600080fd5b602001915036819003821315610dcc57600080fd5b60007fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8203611558577f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b5060010190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602160045260246000fdfea264697066735822122056694a0f8516f09e33000ee7cca7b7c7c726d389f6b102f7392626a3678c862d64736f6c634300080f0033";
    static readonly abi: readonly [{
        readonly inputs: readonly [{
            readonly internalType: "contract IEntryPoint";
            readonly name: "_entryPoint";
            readonly type: "address";
        }, {
            readonly internalType: "address";
            readonly name: "_verifyingSigner";
            readonly type: "address";
        }];
        readonly stateMutability: "nonpayable";
        readonly type: "constructor";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "previousOwner";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "newOwner";
            readonly type: "address";
        }];
        readonly name: "OwnershipTransferred";
        readonly type: "event";
    }, {
        readonly inputs: readonly [{
            readonly internalType: "uint32";
            readonly name: "unstakeDelaySec";
            readonly type: "uint32";
        }];
        readonly name: "addStake";
        readonly outputs: readonly [];
        readonly stateMutability: "payable";
        readonly type: "function";
    }, {
        readonly inputs: readonly [];
        readonly name: "deposit";
        readonly outputs: readonly [];
        readonly stateMutability: "payable";
        readonly type: "function";
    }, {
        readonly inputs: readonly [];
        readonly name: "entryPoint";
        readonly outputs: readonly [{
            readonly internalType: "contract IEntryPoint";
            readonly name: "";
            readonly type: "address";
        }];
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly inputs: readonly [];
        readonly name: "getDeposit";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "";
            readonly type: "uint256";
        }];
        readonly stateMutability: "view";
        readonly type: "function";
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
            readonly internalType: "uint48";
            readonly name: "validUntil";
            readonly type: "uint48";
        }, {
            readonly internalType: "uint48";
            readonly name: "validAfter";
            readonly type: "uint48";
        }];
        readonly name: "getHash";
        readonly outputs: readonly [{
            readonly internalType: "bytes32";
            readonly name: "";
            readonly type: "bytes32";
        }];
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly inputs: readonly [];
        readonly name: "owner";
        readonly outputs: readonly [{
            readonly internalType: "address";
            readonly name: "";
            readonly type: "address";
        }];
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly inputs: readonly [{
            readonly internalType: "bytes";
            readonly name: "paymasterAndData";
            readonly type: "bytes";
        }];
        readonly name: "parsePaymasterAndData";
        readonly outputs: readonly [{
            readonly internalType: "uint48";
            readonly name: "validUntil";
            readonly type: "uint48";
        }, {
            readonly internalType: "uint48";
            readonly name: "validAfter";
            readonly type: "uint48";
        }, {
            readonly internalType: "bytes";
            readonly name: "signature";
            readonly type: "bytes";
        }];
        readonly stateMutability: "pure";
        readonly type: "function";
    }, {
        readonly inputs: readonly [{
            readonly internalType: "enum IPaymaster.PostOpMode";
            readonly name: "mode";
            readonly type: "uint8";
        }, {
            readonly internalType: "bytes";
            readonly name: "context";
            readonly type: "bytes";
        }, {
            readonly internalType: "uint256";
            readonly name: "actualGasCost";
            readonly type: "uint256";
        }];
        readonly name: "postOp";
        readonly outputs: readonly [];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly inputs: readonly [];
        readonly name: "renounceOwnership";
        readonly outputs: readonly [];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "";
            readonly type: "address";
        }];
        readonly name: "senderNonce";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "";
            readonly type: "uint256";
        }];
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "newOwner";
            readonly type: "address";
        }];
        readonly name: "transferOwnership";
        readonly outputs: readonly [];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly inputs: readonly [];
        readonly name: "unlockStake";
        readonly outputs: readonly [];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
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
            readonly name: "userOpHash";
            readonly type: "bytes32";
        }, {
            readonly internalType: "uint256";
            readonly name: "maxCost";
            readonly type: "uint256";
        }];
        readonly name: "validatePaymasterUserOp";
        readonly outputs: readonly [{
            readonly internalType: "bytes";
            readonly name: "context";
            readonly type: "bytes";
        }, {
            readonly internalType: "uint256";
            readonly name: "validationData";
            readonly type: "uint256";
        }];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly inputs: readonly [];
        readonly name: "verifyingSigner";
        readonly outputs: readonly [{
            readonly internalType: "address";
            readonly name: "";
            readonly type: "address";
        }];
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly inputs: readonly [{
            readonly internalType: "address payable";
            readonly name: "withdrawAddress";
            readonly type: "address";
        }];
        readonly name: "withdrawStake";
        readonly outputs: readonly [];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly inputs: readonly [{
            readonly internalType: "address payable";
            readonly name: "withdrawAddress";
            readonly type: "address";
        }, {
            readonly internalType: "uint256";
            readonly name: "amount";
            readonly type: "uint256";
        }];
        readonly name: "withdrawTo";
        readonly outputs: readonly [];
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }];
    static createInterface(): VerifyingPaymasterInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): VerifyingPaymaster;
}
export {};
