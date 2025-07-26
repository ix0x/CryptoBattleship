'use client'

import { useState } from 'react'
import { Coins, TrendingUp, Gift, Loader2 } from 'lucide-react'
import { useCredits } from '@/hooks/useCredits'
import { parseEther, formatEther } from 'viem'

export default function CreditsPanel() {
  const {
    playerCredits,
    totalActiveCredits,
    claimableTokens,
    convertCredits,
    claimTokens,
    isConverting,
    isClaiming,
    convertError,
    claimError,
    isLoading
  } = useCredits()

  const [convertAmount, setConvertAmount] = useState('')

  const handleConvertSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!convertAmount || parseFloat(convertAmount) <= 0) return
    
    try {
      await convertCredits(parseEther(convertAmount))
      setConvertAmount('')
    } catch (error) {
      console.error('Convert failed:', error)
    }
  }

  const maxConvertAmount = parseFloat(playerCredits)

  if (isLoading) {
    return (
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin text-primary mr-2" />
          <span className="text-card-foreground">Loading credits...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Credits Overview */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-bold text-card-foreground mb-4 flex items-center">
          <Coins className="h-5 w-5 mr-2 text-accent" />
          Your Game Credits
        </h3>
        
        <div className="grid md:grid-cols-3 gap-4 mb-6">
          <div className="text-center">
            <div className="text-2xl font-bold text-accent mb-1">
              {parseFloat(playerCredits).toFixed(2)}
            </div>
            <div className="text-sm text-card-foreground/70">Your Credits</div>
            <div className="text-xs text-card-foreground/50 mt-1">
              Earn from battles & decay over time
            </div>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-primary mb-1">
              {parseFloat(totalActiveCredits).toFixed(0)}
            </div>
            <div className="text-sm text-card-foreground/70">Total Active</div>
            <div className="text-xs text-card-foreground/50 mt-1">
              System-wide credits
            </div>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-green-500 mb-1">
              {parseFloat(claimableTokens).toFixed(2)}
            </div>
            <div className="text-sm text-card-foreground/70">Claimable SHIP</div>
            <div className="text-xs text-card-foreground/50 mt-1">
              Ready to claim
            </div>
          </div>
        </div>

        {/* Credit Info */}
        <div className="bg-secondary/10 rounded-lg p-4 mb-4">
          <div className="flex items-start space-x-3">
            <TrendingUp className="h-5 w-5 text-accent mt-0.5" />
            <div className="text-sm text-card-foreground/80">
              <p className="font-medium mb-1">How Credits Work:</p>
              <ul className="space-y-1 text-xs">
                <li>• Earn credits by winning battles and completing games</li>
                <li>• Credits decay over time (50% per epoch) to prevent hoarding</li>
                <li>• Convert credits to SHIP tokens anytime</li>
                <li>• Higher stakes games earn more credits</li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      {/* Convert Credits */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h4 className="text-lg font-semibold text-card-foreground mb-4 flex items-center">
          <Coins className="h-4 w-4 mr-2" />
          Convert Credits to SHIP Tokens
        </h4>
        
        <form onSubmit={handleConvertSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-card-foreground mb-2">
              Amount to Convert
            </label>
            <div className="flex space-x-2">
              <input
                type="number"
                step="0.01"
                min="0"
                max={maxConvertAmount}
                value={convertAmount}
                onChange={(e) => setConvertAmount(e.target.value)}
                placeholder="0.00"
                className="flex-1 px-3 py-2 border border-border rounded-lg bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
              <button
                type="button"
                onClick={() => setConvertAmount(playerCredits)}
                className="px-3 py-2 text-sm bg-secondary text-secondary-foreground border border-border rounded-lg hover:bg-secondary/80 transition-colors"
              >
                Max
              </button>
            </div>
            <div className="text-xs text-card-foreground/60 mt-1">
              Available: {parseFloat(playerCredits).toFixed(2)} credits
            </div>
          </div>
          
          <button
            type="submit"
            disabled={!convertAmount || parseFloat(convertAmount) <= 0 || parseFloat(convertAmount) > maxConvertAmount || isConverting}
            className="w-full px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
          >
            {isConverting ? (
              <span className="flex items-center justify-center">
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
                Converting...
              </span>
            ) : (
              'Convert Credits'
            )}
          </button>
        </form>

        {convertError && (
          <div className="mt-4 p-3 bg-error/10 border border-error/20 rounded-lg">
            <p className="text-error text-sm">
              Error: {(convertError as Error)?.message || 'Failed to convert credits'}
            </p>
          </div>
        )}
      </div>

      {/* Claim Vested Tokens */}
      {parseFloat(claimableTokens) > 0 && (
        <div className="bg-card border border-border rounded-lg p-6">
          <h4 className="text-lg font-semibold text-card-foreground mb-4 flex items-center">
            <Gift className="h-4 w-4 mr-2 text-green-500" />
            Claim Vested Tokens
          </h4>
          
          <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
            <p className="text-sm text-green-800">
              You have <strong>{parseFloat(claimableTokens).toFixed(2)} SHIP tokens</strong> ready to claim from your vesting schedule.
            </p>
          </div>
          
          <button
            onClick={claimTokens}
            disabled={isClaiming}
            className="w-full px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
          >
            {isClaiming ? (
              <span className="flex items-center justify-center">
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
                Claiming...
              </span>
            ) : (
              `Claim ${parseFloat(claimableTokens).toFixed(2)} SHIP Tokens`
            )}
          </button>

          {claimError && (
            <div className="mt-4 p-3 bg-error/10 border border-error/20 rounded-lg">
              <p className="text-error text-sm">
                Error: {(claimError as Error)?.message || 'Failed to claim tokens'}
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  )
}