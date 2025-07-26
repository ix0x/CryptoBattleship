import { useContractRead } from './useContract'
import { formatEther } from 'viem'

export function useProtocolStats() {
  // Total supply of SHIP token
  const { data: totalSupply } = useContractRead(
    'BattleshipToken',
    'totalSupply',
    [],
    { watch: true }
  )

  // Total staked in staking pool
  const { data: totalStaked } = useContractRead(
    'StakingPool',
    'getTotalStaked',
    [],
    { watch: true }
  )

  // Current epoch from tokenomics
  const { data: currentEpoch } = useContractRead(
    'TokenomicsCore',
    'getCurrentEpoch',
    [],
    { watch: true }
  )

  // Weekly emissions
  const { data: weeklyEmissions } = useContractRead(
    'TokenomicsCore',
    'getWeeklyEmissionRate',
    [],
    { watch: true }
  )

  // Epoch progression data
  const { data: epochStartTime } = useContractRead(
    'TokenomicsCore',
    'epochStartTime',
    [],
    { watch: true }
  )

  const { data: epochDuration } = useContractRead(
    'TokenomicsCore',
    'EPOCH_DURATION',
    [],
    { watch: true }
  )

  // Calculate epoch progress
  const getEpochProgress = () => {
    if (!epochStartTime || !epochDuration || !currentEpoch) return null
    
    const now = Math.floor(Date.now() / 1000)
    const epochStart = Number(epochStartTime) + (Number(currentEpoch) - 1) * Number(epochDuration)
    const epochEnd = epochStart + Number(epochDuration)
    const progress = Math.min(100, Math.max(0, ((now - epochStart) / Number(epochDuration)) * 100))
    const timeLeft = Math.max(0, epochEnd - now)
    
    return {
      progress,
      timeLeft,
      epochStart,
      epochEnd,
      isComplete: progress >= 100
    }
  }

  return {
    totalSupply: totalSupply ? formatEther(totalSupply as bigint) : '0',
    totalStaked: totalStaked ? formatEther(totalStaked as bigint) : '0',
    currentEpoch: currentEpoch ? Number(currentEpoch) : 0,
    weeklyEmissions: weeklyEmissions ? formatEther(weeklyEmissions as bigint) : '0',
    epochProgress: getEpochProgress(),
    isLoading: !totalSupply && !totalStaked && !currentEpoch && !weeklyEmissions,
  }
}