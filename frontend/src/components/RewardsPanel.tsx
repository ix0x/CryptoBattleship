'use client'

import { useState } from 'react'
import { Coins, DollarSign, Gift, TrendingUp, Zap } from 'lucide-react'
import PlaceholderImage from './PlaceholderImage'

interface TokenReward {
  symbol: string
  name: string
  address: string
  claimable: string
  locked: string
  icon?: string
}

interface EpochReward {
  epoch: number
  shipEmissions: string
  revenueTokens: TokenReward[]
  unlockProgress: number
  isClaimable: boolean
}

export default function RewardsPanel() {
  const [selectedRewardType, setSelectedRewardType] = useState<'all' | 'ship' | 'revenue'>('all')
  const [isClaimingAll, setIsClaimingAll] = useState(false)

  // Mock data for demonstration
  const supportedTokens: TokenReward[] = [
    { symbol: 'ETH', name: 'Ethereum', address: '0x...', claimable: '0.15', locked: '0.35', icon: undefined },
    { symbol: 'USDC', name: 'USD Coin', address: '0x...', claimable: '125.50', locked: '292.50', icon: undefined },
    { symbol: 'USDT', name: 'Tether USD', address: '0x...', claimable: '89.25', locked: '208.25', icon: undefined },
    { symbol: 'DAI', name: 'Dai Stablecoin', address: '0x...', claimable: '67.80', locked: '158.20', icon: undefined },
  ]

  const epochRewards: EpochReward[] = [
    {
      epoch: 42,
      shipEmissions: '1,250.00',
      revenueTokens: supportedTokens.map(token => ({ ...token, claimable: token.claimable, locked: token.locked })),
      unlockProgress: 73,
      isClaimable: true
    },
    {
      epoch: 41,
      shipEmissions: '1,180.50',
      revenueTokens: supportedTokens.map(token => ({ 
        ...token, 
        claimable: (parseFloat(token.claimable) * 0.8).toFixed(2),
        locked: '0.00'
      })),
      unlockProgress: 100,
      isClaimable: true
    },
    {
      epoch: 40,
      shipEmissions: '1,320.75',
      revenueTokens: supportedTokens.map(token => ({ 
        ...token, 
        claimable: (parseFloat(token.claimable) * 1.1).toFixed(2),
        locked: '0.00'
      })),
      unlockProgress: 100,
      isClaimable: true
    }
  ]

  const totalClaimable = {
    ship: epochRewards.reduce((sum, epoch) => sum + parseFloat(epoch.shipEmissions.replace(',', '')), 0),
    eth: epochRewards.reduce((sum, epoch) => {
      const ethReward = epoch.revenueTokens.find(t => t.symbol === 'ETH')
      return sum + parseFloat(ethReward?.claimable || '0')
    }, 0),
    usdc: epochRewards.reduce((sum, epoch) => {
      const usdcReward = epoch.revenueTokens.find(t => t.symbol === 'USDC')
      return sum + parseFloat(usdcReward?.claimable || '0')
    }, 0)
  }

  const handleClaimAll = async () => {
    setIsClaimingAll(true)
    // Simulate batch claim transaction
    await new Promise(resolve => setTimeout(resolve, 3000))
    setIsClaimingAll(false)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-accent/10 rounded-lg">
              <Gift className="h-6 w-6 text-accent" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-card-foreground">Your Rewards</h2>
              <p className="text-card-foreground/70">SHIP emissions and multi-token revenue</p>
            </div>
          </div>
          
          <button
            onClick={handleClaimAll}
            disabled={isClaimingAll}
            className="flex items-center space-x-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
          >
            {isClaimingAll ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-2 border-primary-foreground border-t-transparent"></div>
                <span>Claiming...</span>
              </>
            ) : (
              <>
                <Zap className="h-4 w-4" />
                <span>Claim All</span>
              </>
            )}
          </button>
        </div>

        {/* Reward Type Filter */}
        <div className="flex space-x-1 bg-secondary/20 rounded-lg p-1 max-w-md">
          <button
            onClick={() => setSelectedRewardType('all')}
            className={`px-4 py-2 rounded-md transition-colors flex-1 text-center ${
              selectedRewardType === 'all' 
                ? 'bg-primary text-primary-foreground' 
                : 'text-card-foreground/70 hover:text-card-foreground'
            }`}
          >
            All Rewards
          </button>
          <button
            onClick={() => setSelectedRewardType('ship')}
            className={`px-4 py-2 rounded-md transition-colors flex-1 text-center ${
              selectedRewardType === 'ship' 
                ? 'bg-primary text-primary-foreground' 
                : 'text-card-foreground/70 hover:text-card-foreground'
            }`}
          >
            SHIP Emissions
          </button>
          <button
            onClick={() => setSelectedRewardType('revenue')}
            className={`px-4 py-2 rounded-md transition-colors flex-1 text-center ${
              selectedRewardType === 'revenue' 
                ? 'bg-primary text-primary-foreground' 
                : 'text-card-foreground/70 hover:text-card-foreground'
            }`}
          >
            Revenue Tokens
          </button>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid md:grid-cols-3 gap-4">
        <div className="bg-card border border-border rounded-lg p-6">
          <div className="flex items-center space-x-3 mb-3">
            <Coins className="h-5 w-5 text-accent" />
            <span className="font-semibold text-card-foreground">SHIP Tokens</span>
          </div>
          <div className="text-2xl font-bold text-card-foreground mb-1">
            {totalClaimable.ship.toLocaleString()} SHIP
          </div>
          <div className="text-sm text-card-foreground/60">Available to claim</div>
        </div>

        <div className="bg-card border border-border rounded-lg p-6">
          <div className="flex items-center space-x-3 mb-3">
            <DollarSign className="h-5 w-5 text-accent" />
            <span className="font-semibold text-card-foreground">ETH Revenue</span>
          </div>
          <div className="text-2xl font-bold text-card-foreground mb-1">
            {totalClaimable.eth.toFixed(3)} ETH
          </div>
          <div className="text-sm text-card-foreground/60">≈ ${(totalClaimable.eth * 2800).toFixed(0)} USD</div>
        </div>

        <div className="bg-card border border-border rounded-lg p-6">
          <div className="flex items-center space-x-3 mb-3">
            <TrendingUp className="h-5 w-5 text-accent" />
            <span className="font-semibold text-card-foreground">USDC Revenue</span>
          </div>
          <div className="text-2xl font-bold text-card-foreground mb-1">
            {totalClaimable.usdc.toFixed(2)} USDC
          </div>
          <div className="text-sm text-card-foreground/60">Stable value</div>
        </div>
      </div>

      {/* Epoch Rewards */}
      <div className="space-y-4">
        {epochRewards.map((epochReward) => (
          <div key={epochReward.epoch} className="bg-card border border-border rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center space-x-3">
                <div className="text-lg font-bold text-card-foreground">Epoch {epochReward.epoch}</div>
                <div className="px-2 py-1 bg-accent/20 text-accent text-sm rounded">
                  {epochReward.unlockProgress}% unlocked
                </div>
              </div>
              {epochReward.isClaimable && (
                <button className="px-4 py-2 bg-secondary text-secondary-foreground border border-border rounded-lg hover:bg-secondary/80 transition-colors">
                  Claim Epoch
                </button>
              )}
            </div>

            <div className="grid md:grid-cols-2 gap-6">
              {/* SHIP Emissions */}
              {(selectedRewardType === 'all' || selectedRewardType === 'ship') && (
                <div>
                  <h4 className="font-semibold text-card-foreground mb-3 flex items-center">
                    <Coins className="h-4 w-4 mr-2 text-accent" />
                    SHIP Emissions
                  </h4>
                  <div className="bg-secondary/10 rounded-lg p-4">
                    <div className="flex justify-between items-center mb-2">
                      <span className="text-card-foreground/80">Available:</span>
                      <span className="font-semibold text-card-foreground">{epochReward.shipEmissions} SHIP</span>
                    </div>
                    <div className="w-full bg-secondary/20 rounded-full h-2 mb-2">
                      <div 
                        className="bg-accent h-2 rounded-full transition-all duration-300"
                        style={{ width: `${epochReward.unlockProgress}%` }}
                      />
                    </div>
                    <div className="text-xs text-card-foreground/60">
                      Linear unlock: {epochReward.unlockProgress}% available
                    </div>
                  </div>
                </div>
              )}

              {/* Revenue Tokens */}
              {(selectedRewardType === 'all' || selectedRewardType === 'revenue') && (
                <div>
                  <h4 className="font-semibold text-card-foreground mb-3 flex items-center">
                    <DollarSign className="h-4 w-4 mr-2 text-accent" />
                    Revenue Tokens
                  </h4>
                  <div className="space-y-2">
                    {epochReward.revenueTokens.map((token) => (
                      parseFloat(token.claimable) > 0 && (
                        <div key={token.symbol} className="bg-secondary/10 rounded-lg p-3">
                          <div className="flex items-center justify-between">
                            <div className="flex items-center space-x-2">
                              <PlaceholderImage width={24} height={24} text={token.symbol} className="rounded-full" />
                              <span className="font-medium text-card-foreground">{token.symbol}</span>
                            </div>
                            <div className="text-right">
                              <div className="font-semibold text-card-foreground">{token.claimable}</div>
                              {parseFloat(token.locked) > 0 && (
                                <div className="text-xs text-card-foreground/60">+{token.locked} locked</div>
                              )}
                            </div>
                          </div>
                        </div>
                      )
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Info Panel */}
      <div className="bg-accent/10 border border-accent/20 rounded-lg p-4">
        <h4 className="font-semibold text-card-foreground mb-2">How Rewards Work</h4>
        <div className="text-sm text-card-foreground/80 space-y-1">
          <p>• <strong>SHIP Emissions:</strong> Based on your credits from game participation</p>
          <p>• <strong>Revenue Tokens:</strong> Based on your weighted stake amount</p>
          <p>• <strong>Linear Unlock:</strong> Rewards unlock gradually over each 7-day epoch</p>
          <p>• <strong>Multi-Token:</strong> Revenue distributed in original tokens (no conversion)</p>
        </div>
      </div>
    </div>
  )
}