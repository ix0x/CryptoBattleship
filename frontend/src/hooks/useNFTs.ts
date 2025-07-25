import { useAccount } from 'wagmi'
import { useContractRead } from './useContract'
import { useState, useEffect } from 'react'

export interface NFT {
  id: string
  type: 'SHIP' | 'ACTION' | 'CAPTAIN' | 'CREW'
  rarity: 'COMMON' | 'UNCOMMON' | 'RARE' | 'EPIC' | 'LEGENDARY'
  name: string
  tokenURI?: string
  svgData?: string
  attributes: Record<string, string | number>
  contractAddress: string
}


export function useUserNFTs() {
  const { address } = useAccount()
  const [nfts, setNfts] = useState<NFT[]>([])
  const [isLoading, setIsLoading] = useState(false)

  // Get balance for each NFT type
  const { data: shipBalance } = useContractRead('ShipNFTManager', 'balanceOf', address ? [address] : undefined, { enabled: !!address })
  const { data: actionBalance } = useContractRead('ActionNFTManager', 'balanceOf', address ? [address] : undefined, { enabled: !!address })
  const { data: captainBalance } = useContractRead('CaptainNFTManager', 'balanceOf', address ? [address] : undefined, { enabled: !!address })
  const { data: crewBalance } = useContractRead('CrewNFTManager', 'balanceOf', address ? [address] : undefined, { enabled: !!address })

  useEffect(() => {
    if (!address) {
      setNfts([])
      return
    }

    const fetchNFTs = async () => {
      setIsLoading(true)
      const allNfts: NFT[] = []

      // Fetch NFTs for each type
      const nftTypes = [
        { type: 'SHIP' as const, balance: shipBalance },
        { type: 'ACTION' as const, balance: actionBalance },
        { type: 'CAPTAIN' as const, balance: captainBalance },
        { type: 'CREW' as const, balance: crewBalance },
      ]

      for (const { type, balance } of nftTypes) {
        if (balance && Number(balance) > 0) {
          // For now, we'll create mock NFTs based on balance
          // In production, you'd fetch tokenByIndex and tokenURI for each
          for (let i = 0; i < Number(balance); i++) {
            allNfts.push(createMockNFT(type, i))
          }
        }
      }

      setNfts(allNfts)
      setIsLoading(false)
    }

    fetchNFTs()
  }, [address, shipBalance, actionBalance, captainBalance, crewBalance])

  return {
    nfts,
    isLoading,
    totalCount: nfts.length,
    shipCount: nfts.filter(n => n.type === 'SHIP').length,
    actionCount: nfts.filter(n => n.type === 'ACTION').length,
    captainCount: nfts.filter(n => n.type === 'CAPTAIN').length,
    crewCount: nfts.filter(n => n.type === 'CREW').length,
  }
}

// Helper function to create mock NFT data while we don't have full metadata fetching
function createMockNFT(type: NFT['type'], index: number): NFT {
  const rarities: NFT['rarity'][] = ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY']
  const rarity = rarities[index % rarities.length]

  const baseNFT = {
    id: `${type.toLowerCase()}_${index}`,
    type,
    rarity,
    contractAddress: '', // Will be populated with actual addresses
  }

  switch (type) {
    case 'SHIP':
      return {
        ...baseNFT,
        name: `Battle Ship #${index + 1}`,
        attributes: {
          shipType: 'BATTLESHIP',
          size: 4,
          speed: 1,
          damage: 85,
          health: 120,
        },
      }
    case 'CAPTAIN':
      return {
        ...baseNFT,
        name: `Admiral #${index + 1}`,
        attributes: {
          ability: 'DAMAGE_BOOST',
          boost: 15,
          experience: 750,
        },
      }
    case 'CREW':
      return {
        ...baseNFT,
        name: `Crew Member #${index + 1}`,
        attributes: {
          crewType: 'GUNNER',
          boost: 8,
          specialty: 'Artillery',
        },
      }
    case 'ACTION':
      return {
        ...baseNFT,
        name: `Action Card #${index + 1}`,
        attributes: {
          category: 'OFFENSIVE',
          damage: 75,
          range: 3,
        },
      }
    default:
      return baseNFT as NFT
  }
}