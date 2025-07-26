import { useAccount } from 'wagmi'
import { useContractRead, useContractWrite } from './useContract'
import { formatEther } from 'viem'

export function useCredits() {
  const { address } = useAccount()

  // Get player's current credits with decay applied
  const { data: playerCredits, refetch: refetchCredits } = useContractRead(
    'TokenomicsCore',
    'getPlayerCredits',
    address ? [address] : undefined,
    { enabled: !!address, watch: true }
  )

  // Get total active credits in the system
  const { data: totalActiveCredits } = useContractRead(
    'TokenomicsCore',
    'getTotalActiveCredits',
    [],
    { watch: true }
  )

  // Get claimable vested tokens
  const { data: claimableTokens } = useContractRead(
    'TokenomicsCore',
    'getClaimableVestedTokens',
    address ? [address] : undefined,
    { enabled: !!address, watch: true }
  )

  // Convert credits to tokens
  const { writeContract: convertCredits, isPending: isConverting, error: convertError } = useContractWrite('TokenomicsCore')

  // Claim vested tokens
  const { writeContract: claimTokens, isPending: isClaiming, error: claimError } = useContractWrite('TokenomicsCore')

  const handleConvertCredits = async (amount: bigint) => {
    if (!address) return
    try {
      await convertCredits('convertCreditsToTokens', [amount])
      refetchCredits()
    } catch (error) {
      console.error('Failed to convert credits:', error)
    }
  }

  const handleClaimTokens = async () => {
    if (!address) return
    try {
      await claimTokens('claimVestedTokens', [])
      refetchCredits()
    } catch (error) {
      console.error('Failed to claim tokens:', error)
    }
  }

  return {
    playerCredits: playerCredits ? formatEther(playerCredits as bigint) : '0',
    totalActiveCredits: totalActiveCredits ? formatEther(totalActiveCredits as bigint) : '0',
    claimableTokens: claimableTokens ? formatEther(claimableTokens as bigint) : '0',
    convertCredits: handleConvertCredits,
    claimTokens: handleClaimTokens,
    isConverting,
    isClaiming,
    convertError,
    claimError,
    refetchCredits,
    isLoading: !playerCredits && !totalActiveCredits && !claimableTokens && !!address
  }
}