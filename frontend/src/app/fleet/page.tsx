'use client'

import { useState } from 'react'
import { ArrowLeft, Anchor, Shield, Users, Zap } from 'lucide-react'
import Link from 'next/link'
import NFTCard from '@/components/NFTCard'
import NFTDetails from '@/components/NFTDetails'
import { useUserNFTs, type NFT } from '@/hooks/useNFTs'
import ConnectWallet from '@/components/ConnectWallet'
import { useAccount } from 'wagmi'


export default function FleetPage() {
  const [selectedNFT, setSelectedNFT] = useState<NFT | null>(null)
  const [filter, setFilter] = useState<'ALL' | 'SHIP' | 'ACTION' | 'CAPTAIN' | 'CREW'>('ALL')
  const { isConnected } = useAccount()
  const { nfts, isLoading, totalCount } = useUserNFTs()

  const filteredNFTs = filter === 'ALL' ? nfts : nfts.filter(nft => nft.type === filter)

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
              {!isConnected ? (
                <ConnectWallet />
              ) : (
                <div className="text-sm text-foreground/80">
                  Total NFTs: <span className="text-primary font-semibold">{totalCount}</span>
                </div>
              )}
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
            {!isConnected ? (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">🔌</div>
                <h3 className="text-xl font-semibold text-foreground mb-2">Connect Your Wallet</h3>
                <p className="text-foreground/70 mb-6">Connect your wallet to view your NFT collection</p>
                <ConnectWallet />
              </div>
            ) : isLoading ? (
              <div className="text-center py-12">
                <div className="animate-spin rounded-full h-12 w-12 border-2 border-primary border-t-transparent mx-auto mb-4"></div>
                <h3 className="text-xl font-semibold text-foreground mb-2">Loading Your Fleet...</h3>
                <p className="text-foreground/70">Fetching your NFTs from the blockchain</p>
              </div>
            ) : (
              <>
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

                {filteredNFTs.length === 0 && totalCount > 0 && (
                  <div className="text-center py-12">
                    <div className="text-6xl mb-4">🏴‍☠️</div>
                    <h3 className="text-xl font-semibold text-foreground mb-2">No {filter.toLowerCase()} NFTs found</h3>
                    <p className="text-foreground/70">Try a different filter or mint some new NFTs!</p>
                  </div>
                )}

                {filteredNFTs.length === 0 && totalCount === 0 && (
                  <div className="text-center py-12">
                    <div className="text-6xl mb-4">⚓</div>
                    <h3 className="text-xl font-semibold text-foreground mb-2">No NFTs Yet</h3>
                    <p className="text-foreground/70">Open some lootboxes to start building your fleet!</p>
                  </div>
                )}
              </>
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