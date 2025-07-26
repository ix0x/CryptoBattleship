'use client'

import { useState } from 'react'
import { Package, Gift, Coins, Zap } from 'lucide-react'
import { useLootbox } from '@/hooks/useLootbox'
import { useAccount } from 'wagmi'
import { formatEther } from 'viem'
import ConnectWallet from './ConnectWallet'

export default function LootboxPanel() {
  const [openCount, setOpenCount] = useState(1)
  const [purchaseCount, setPurchaseCount] = useState(1)
  const { isConnected } = useAccount()
  const { 
    lootboxPrice, 
    unopenedCount, 
    buyLootbox, 
    openLootboxes,
    isPurchasing,
    isOpening,
    purchaseError,
    openError
  } = useLootbox()

  const handlePurchase = async () => {
    try {
      await buyLootbox()
    } catch (error) {
      console.error('Purchase failed:', error)
    }
  }

  const handleBatchPurchase = async () => {
    try {
      // For batch purchases, call buyLootbox multiple times in sequence
      for (let i = 0; i < purchaseCount; i++) {
        await buyLootbox()
        // Small delay between purchases to avoid rate limiting
        if (i < purchaseCount - 1) {
          await new Promise(resolve => setTimeout(resolve, 1000))
        }
      }
    } catch (error) {
      console.error('Batch purchase failed:', error)
    }
  }

  const handleOpen = async () => {
    try {
      await openLootboxes(openCount)
    } catch (error) {
      console.error('Opening failed:', error)
    }
  }

  if (!isConnected) {
    return (
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="text-center py-8">
          <Package className="h-12 w-12 text-accent mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-card-foreground mb-2">Connect to Access Lootboxes</h3>
          <p className="text-card-foreground/70 mb-6">Connect your wallet to purchase and open lootboxes</p>
          <ConnectWallet />
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Purchase Lootbox */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-6">
          <div className="p-2 bg-accent/10 rounded-lg">
            <Gift className="h-6 w-6 text-accent" />
          </div>
          <div>
            <h2 className="text-2xl font-bold text-card-foreground">Purchase Lootbox</h2>
            <p className="text-card-foreground/70">Get random NFTs including ships, captains, crew, and actions</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="bg-secondary/20 border border-secondary rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-card-foreground/70">Price per Lootbox:</span>
              <span className="font-semibold text-card-foreground">
                {lootboxPrice ? `${formatEther(lootboxPrice as bigint)} S` : 'Loading...'}
              </span>
            </div>
            <div className="text-xs text-card-foreground/60">
              Each lootbox contains 4-5 random NFTs with guaranteed rarities
            </div>
          </div>

          {/* Batch Purchase Controls */}
          <div className="space-y-3">
            <div>
              <label className="block text-sm font-medium text-card-foreground mb-2">
                Batch Purchase
              </label>
              <div className="flex items-center space-x-3">
                <div className="flex items-center space-x-2">
                  <button
                    onClick={() => setPurchaseCount(Math.max(1, purchaseCount - 1))}
                    className="px-2 py-1 bg-secondary text-secondary-foreground rounded hover:bg-secondary/80"
                  >
                    -
                  </button>
                  <span className="px-3 py-1 bg-background border border-border rounded min-w-[3rem] text-center">
                    {purchaseCount}
                  </span>
                  <button
                    onClick={() => setPurchaseCount(Math.min(20, purchaseCount + 1))}
                    className="px-2 py-1 bg-secondary text-secondary-foreground rounded hover:bg-secondary/80"
                  >
                    +
                  </button>
                </div>
                <div className="text-sm text-card-foreground/70">
                  Total: {lootboxPrice ? formatEther((lootboxPrice as bigint) * BigInt(purchaseCount)) : '0'} S
                </div>
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-3">
              <button
                onClick={handlePurchase}
                disabled={isPurchasing || !lootboxPrice}
                className="flex items-center justify-center space-x-2 px-4 py-3 bg-accent text-accent-foreground rounded-lg hover:bg-accent/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
              >
                {isPurchasing ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-2 border-accent-foreground border-t-transparent"></div>
                    <span>Buying...</span>
                  </>
                ) : (
                  <>
                    <Gift className="h-4 w-4" />
                    <span>Buy 1</span>
                  </>
                )}
              </button>
              
              <button
                onClick={handleBatchPurchase}
                disabled={isPurchasing || !lootboxPrice || purchaseCount < 2}
                className="flex items-center justify-center space-x-2 px-4 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
              >
                {isPurchasing ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-2 border-primary-foreground border-t-transparent"></div>
                    <span>Buying...</span>
                  </>
                ) : (
                  <>
                    <Package className="h-4 w-4" />
                    <span>Buy {purchaseCount}</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {purchaseError && (
            <div className="p-3 bg-error/10 border border-error/20 rounded-lg">
              <p className="text-error text-sm">
                Error: {(purchaseError as Error)?.message || 'Purchase failed'}
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Open Lootboxes */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-6">
          <div className="p-2 bg-primary/10 rounded-lg">
            <Package className="h-6 w-6 text-primary" />
          </div>
          <div>
            <h2 className="text-2xl font-bold text-card-foreground">Open Lootboxes</h2>
            <p className="text-card-foreground/70">You have {unopenedCount} unopened lootbox{unopenedCount !== 1 ? 'es' : ''}</p>
          </div>
        </div>

        {unopenedCount > 0 ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-card-foreground mb-2">
                Number to Open
              </label>
              <div className="flex items-center space-x-3">
                <input
                  type="number"
                  min="1"
                  max={unopenedCount}
                  value={openCount}
                  onChange={(e) => setOpenCount(Math.min(Math.max(1, parseInt(e.target.value) || 1), unopenedCount))}
                  className="flex-1 px-4 py-2 bg-input border border-border rounded-lg text-card-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"
                />
                <button
                  onClick={() => setOpenCount(unopenedCount)}
                  className="px-4 py-2 text-primary hover:text-primary/80 transition-colors"
                >
                  Max
                </button>
              </div>
            </div>

            {/* Quick Batch Buttons */}
            <div className="flex gap-2 mb-4">
              <button
                onClick={() => setOpenCount(5)}
                disabled={unopenedCount < 5}
                className="flex-1 px-3 py-2 bg-secondary text-secondary-foreground rounded hover:bg-secondary/80 disabled:opacity-50 text-sm"
              >
                Open 5
              </button>
              <button
                onClick={() => setOpenCount(10)}
                disabled={unopenedCount < 10}
                className="flex-1 px-3 py-2 bg-secondary text-secondary-foreground rounded hover:bg-secondary/80 disabled:opacity-50 text-sm"
              >
                Open 10
              </button>
              <button
                onClick={() => setOpenCount(20)}
                disabled={unopenedCount < 20}
                className="flex-1 px-3 py-2 bg-secondary text-secondary-foreground rounded hover:bg-secondary/80 disabled:opacity-50 text-sm"
              >
                Open 20
              </button>
            </div>

            {openError && (
              <div className="p-3 bg-error/10 border border-error/20 rounded-lg">
                <p className="text-error text-sm">
                  Error: {(openError as Error)?.message || 'Opening failed'}
                </p>
              </div>
            )}

            <button
              onClick={handleOpen}
              disabled={isOpening || openCount < 1}
              className="w-full flex items-center justify-center space-x-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
            >
              {isOpening ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-2 border-primary-foreground border-t-transparent"></div>
                  <span>Opening...</span>
                </>
              ) : (
                <>
                  <Zap className="h-4 w-4" />
                  <span>Open {openCount} Lootbox{openCount !== 1 ? 'es' : ''}</span>
                </>
              )}
            </button>
          </div>
        ) : (
          <div className="text-center py-6">
            <div className="text-4xl mb-3">📦</div>
            <p className="text-card-foreground/70">No lootboxes to open</p>
            <p className="text-card-foreground/60 text-sm">Purchase lootboxes above to get started</p>
          </div>
        )}
      </div>
    </div>
  )
}