import { useAccount } from 'wagmi'
import { useContractRead, useContractWrite } from './useContract'
import { parseUnits, formatEther } from 'viem'

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

  // Get supported revenue tokens
  const { data: supportedTokens } = useContractRead(
    'StakingPool',
    'getSupportedRevenueTokens',
    [],
    { watch: true }
  )

  // Get user's claimable rewards for each token
  const { data: claimableRewards } = useContractRead(
    'StakingPool',
    'getClaimableRewards',
    address ? [address] : undefined,
    { enabled: !!address, watch: true }
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

  const { 
    writeContract: emergencyUnstake, 
    isPending: isEmergencyUnstaking,
    error: emergencyUnstakeError 
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

  const emergencyUnstakeTokens = async (stakeId: number) => {
    return emergencyUnstake('emergencyUnstake', [stakeId])
  }

  const claimSpecificToken = async (tokenAddress: string) => {
    return claimRewards('claimRewards', [tokenAddress])
  }

  const refetchAll = () => {
    refetchStaked()
    refetchInfo()
  }

  return {
    // Data
    totalStaked: totalStaked as bigint | undefined,
    stakingInfo,
    supportedTokens: supportedTokens as string[] | undefined,
    claimableRewards: claimableRewards as { token: string; amount: bigint }[] | undefined,
    
    // Actions
    stakeTokens,
    unstakeTokens,
    claimStakingRewards,
    emergencyUnstakeTokens,
    claimSpecificToken,
    refetchAll,
    
    // States
    isStaking,
    isUnstaking,
    isClaiming,
    isEmergencyUnstaking,
    isStakeConfirmed,
    isUnstakeConfirmed,
    isClaimConfirmed,
    
    // Errors
    stakeError,
    unstakeError,
    claimError,
    emergencyUnstakeError,
  }
}