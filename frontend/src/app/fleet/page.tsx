'use client'

import { useState } from 'react'
import { ArrowLeft, Anchor, Shield, Users, Zap } from 'lucide-react'
import Link from 'next/link'
import NFTCard from '@/components/NFTCard'
import NFTDetails from '@/components/NFTDetails'

interface NFT {
  id: string
  type: 'SHIP' | 'ACTION' | 'CAPTAIN' | 'CREW'
  rarity: 'COMMON' | 'UNCOMMON' | 'RARE' | 'EPIC' | 'LEGENDARY'
  name: string
  tokenURI?: string
  svgData?: string
  attributes: Record<string, string | number>
}

export default function FleetPage() {
  const [selectedNFT, setSelectedNFT] = useState<NFT | null>(null)
  const [filter, setFilter] = useState<'ALL' | 'SHIP' | 'ACTION' | 'CAPTAIN' | 'CREW'>('ALL')

  // Mock NFT data - in production this would come from the blockchain
  const mockNFTs: NFT[] = [
    {
      id: '1',
      type: 'SHIP',
      rarity: 'EPIC',
      name: 'HMS Thunderstrike',
      attributes: {
        shipType: 'BATTLESHIP',
        size: 4,
        speed: 1,
        damage: 85,
        health: 120
      }
    },
    {
      id: '2',
      type: 'CAPTAIN',
      rarity: 'RARE',
      name: 'Admiral Blackwater',
      attributes: {
        ability: 'DAMAGE_BOOST',
        boost: 15,
        experience: 750
      }
    },
    {
      id: '3',
      type: 'SHIP',
      rarity: 'COMMON',
      name: 'Swift Corsair',
      attributes: {
        shipType: 'DESTROYER',
        size: 2,
        speed: 3,
        damage: 45,
        health: 60
      }
    },
    {
      id: '4',
      type: 'CREW',
      rarity: 'UNCOMMON',
      name: 'Master Gunner',
      attributes: {
        crewType: 'GUNNER',
        boost: 8,
        specialty: 'Artillery'
      }
    },
    {
      id: '5',
      type: 'ACTION',
      rarity: 'RARE',
      name: 'Torpedo Barrage',
      attributes: {
        category: 'OFFENSIVE',
        damage: 75,
        range: 3
      }
    },
    {
      id: '6',
      type: 'SHIP',
      rarity: 'LEGENDARY',
      name: 'Leviathan',
      attributes: {
        shipType: 'CARRIER',
        size: 5,
        speed: 1,
        damage: 100,
        health: 200
      }
    }
  ]

  const filteredNFTs = filter === 'ALL' ? mockNFTs : mockNFTs.filter(nft => nft.type === filter)

  const rarityColors = {
    COMMON: 'border-gray-400 bg-gray-400/10',
    UNCOMMON: 'border-green-400 bg-green-400/10',
    RARE: 'border-blue-400 bg-blue-400/10',
    EPIC: 'border-purple-400 bg-purple-400/10',
    LEGENDARY: 'border-orange-400 bg-orange-400/10'
  }

  const typeIcons = {
    SHIP: Anchor,
    ACTION: Zap,
    CAPTAIN: Shield,
    CREW: Users
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/" className="flex items-center space-x-2 text-foreground hover:text-primary transition-colors">
                <ArrowLeft className="h-5 w-5" />
                <span>Back to Home</span>
              </Link>
              <div className="h-6 w-px bg-border"></div>
              <h1 className="text-2xl font-bold text-foreground">Your Fleet</h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-foreground/80">
                Total NFTs: <span className="text-primary font-semibold">{mockNFTs.length}</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <div className="flex flex-col lg:flex-row gap-8">
          {/* Filters and NFT Grid */}
          <div className="flex-1">
            {/* Filter Tabs */}
            <div className="flex space-x-1 bg-card/30 rounded-lg p-1 mb-8 max-w-2xl">
              {['ALL', 'SHIP', 'ACTION', 'CAPTAIN', 'CREW'].map((filterType) => {
                const Icon = filterType === 'ALL' ? null : typeIcons[filterType as keyof typeof typeIcons]
                return (
                  <button
                    key={filterType}
                    onClick={() => setFilter(filterType as 'ALL' | 'SHIP' | 'ACTION' | 'CAPTAIN' | 'CREW')}
                    className={`flex items-center space-x-2 px-4 py-2 rounded-md transition-colors flex-1 justify-center ${
                      filter === filterType 
                        ? 'bg-primary text-primary-foreground' 
                        : 'text-foreground/70 hover:text-foreground'
                    }`}
                  >
                    {Icon && <Icon className="h-4 w-4" />}
                    <span>{filterType}</span>
                  </button>
                )
              })}
            </div>

            {/* NFT Grid */}
            <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {filteredNFTs.map((nft) => (
                <NFTCard
                  key={nft.id}
                  nft={nft}
                  onClick={() => setSelectedNFT(nft)}
                  isSelected={selectedNFT?.id === nft.id}
                  rarityColors={rarityColors}
                  typeIcons={typeIcons}
                />
              ))}
            </div>

            {filteredNFTs.length === 0 && (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">🏴‍☠️</div>
                <h3 className="text-xl font-semibold text-foreground mb-2">No {filter.toLowerCase()} NFTs found</h3>
                <p className="text-foreground/70">Try a different filter or mint some new NFTs!</p>
              </div>
            )}
          </div>

          {/* NFT Details Panel */}
          {selectedNFT && (
            <div className="lg:w-96">
              <NFTDetails 
                nft={selectedNFT} 
                onClose={() => setSelectedNFT(null)}
                rarityColors={rarityColors}
                typeIcons={typeIcons}
              />
            </div>
          )}
        </div>
      </main>
    </div>
  )
}