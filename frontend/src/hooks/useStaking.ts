import { useAccount } from 'wagmi'
import { useContractRead, useContractWrite } from './useContract'
import { parseUnits } from 'viem'

export function useStaking() {
  const { address } = useAccount()
  
  // Read current staking info
  const { data: totalStaked, refetch: refetchStaked } = useContractRead(
    'StakingPool',
    'getTotalStaked',
    address ? [address] : undefined,
    { enabled: !!address }
  )

  const { data: stakingInfo, refetch: refetchInfo } = useContractRead(
    'StakingPool',
    'getStakingInfo',
    address ? [address] : undefined,
    { enabled: !!address }
  )

  // Write functions
  const { 
    writeContract: stake, 
    isPending: isStaking,
    isConfirmed: isStakeConfirmed,
    error: stakeError 
  } = useContractWrite('StakingPool')

  const { 
    writeContract: unstake, 
    isPending: isUnstaking,
    isConfirmed: isUnstakeConfirmed,
    error: unstakeError 
  } = useContractWrite('StakingPool')

  const { 
    writeContract: claimRewards, 
    isPending: isClaiming,
    isConfirmed: isClaimConfirmed,
    error: claimError 
  } = useContractWrite('StakingPool')

  const stakeTokens = async (amount: string, lockWeeks: number) => {
    const amountWei = parseUnits(amount, 18)
    return stake('stake', [amountWei, lockWeeks])
  }

  const unstakeTokens = async (stakeId: number) => {
    return unstake('unstake', [stakeId])
  }

  const claimStakingRewards = async () => {
    return claimRewards('claimRewards', [])
  }

  const refetchAll = () => {
    refetchStaked()
    refetchInfo()
  }

  return {
    // Data
    totalStaked: totalStaked as bigint | undefined,
    stakingInfo,
    
    // Actions
    stakeTokens,
    unstakeTokens,
    claimStakingRewards,
    refetchAll,
    
    // States
    isStaking,
    isUnstaking,
    isClaiming,
    isStakeConfirmed,
    isUnstakeConfirmed,
    isClaimConfirmed,
    
    // Errors
    stakeError,
    unstakeError,
    claimError,
  }
}