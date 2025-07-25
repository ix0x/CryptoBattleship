import { useAccount } from 'wagmi'
import { useContractRead } from './useContract'
import { formatUnits } from 'viem'

export function useTokenBalance() {
  const { address } = useAccount()
  
  const { data: balance, isLoading, error, refetch } = useContractRead(
    'BattleshipToken',
    'balanceOf',
    address ? [address] : undefined,
    {
      enabled: !!address,
      watch: true,
    }
  )

  const formattedBalance = balance ? formatUnits(balance as bigint, 18) : '0'

  return {
    balance: formattedBalance,
    rawBalance: balance as bigint | undefined,
    isLoading,
    error,
    refetch,
  }
}