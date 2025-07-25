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
    'getWeeklyEmissions',
    [],
    { watch: true }
  )

  return {
    totalSupply: totalSupply ? formatEther(totalSupply as bigint) : '0',
    totalStaked: totalStaked ? formatEther(totalStaked as bigint) : '0',
    currentEpoch: currentEpoch ? Number(currentEpoch) : 0,
    weeklyEmissions: weeklyEmissions ? formatEther(weeklyEmissions as bigint) : '0',
    isLoading: !totalSupply && !totalStaked && !currentEpoch && !weeklyEmissions,
  }
}