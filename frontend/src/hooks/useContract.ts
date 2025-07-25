import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { CONTRACT_ADDRESSES, type ContractName } from '@/lib/config'
import { ABIS, type AbiName } from '@/lib/abis'

export function useContractRead(
  contractName: ContractName & AbiName,
  functionName: string,
  args?: readonly unknown[],
  options?: any
) {
  return useReadContract({
    address: CONTRACT_ADDRESSES[contractName] as `0x${string}`,
    abi: ABIS[contractName] as any,
    functionName: functionName as any,
    args: args as any,
    ...options,
  } as any)
}

export function useContractWrite(
  contractName: ContractName & AbiName
) {
  const { writeContract, data: hash, error, isPending } = useWriteContract()
  
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  const writeContractAsync = (functionName: string, args?: readonly unknown[], options?: any) => {
    return writeContract({
      address: CONTRACT_ADDRESSES[contractName] as `0x${string}`,
      abi: ABIS[contractName] as any,
      functionName: functionName as any,
      args: args as any,
      ...options,
    } as any)
  }

  return {
    writeContract: writeContractAsync,
    hash,
    error,
    isPending,
    isConfirming,
    isConfirmed,
  }
}