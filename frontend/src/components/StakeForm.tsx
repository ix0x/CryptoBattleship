'use client'

import { useState } from 'react'
import { Coins, Info, Lock, Zap } from 'lucide-react'
import { useTokenBalance } from '@/hooks/useTokenBalance'
import { useStaking } from '@/hooks/useStaking'
import { useAccount } from 'wagmi'
import ConnectWallet from './ConnectWallet'

export default function StakeForm() {
  const [amount, setAmount] = useState('')
  const [lockPeriod, setLockPeriod] = useState('1') // weeks
  const { isConnected } = useAccount()
  const { balance, isLoading: balanceLoading } = useTokenBalance()
  const { stakeTokens, isStaking, isStakeConfirmed, stakeError } = useStaking()

  const lockOptions = [
    { weeks: '1', multiplier: '1.0x', label: '1 Week' },
    { weeks: '4', multiplier: '1.1x', label: '1 Month' },
    { weeks: '12', multiplier: '1.3x', label: '3 Months' },
    { weeks: '26', multiplier: '1.5x', label: '6 Months' },
    { weeks: '52', multiplier: '2.0x', label: '1 Year' },
  ]

  const selectedOption = lockOptions.find(opt => opt.weeks === lockPeriod)
  const estimatedRewards = amount ? (parseFloat(amount) * 0.15 * parseFloat(selectedOption?.multiplier || '1')).toFixed(2) : '0'

  const handleStake = async () => {
    if (!amount || parseFloat(amount) <= 0 || !isConnected) return
    
    try {
      await stakeTokens(amount, parseInt(lockPeriod))
      // Reset form on success
      if (isStakeConfirmed) {
        setAmount('')
        setLockPeriod('1')
      }
    } catch (error) {
      console.error('Staking failed:', error)
    }
  }

  const setMaxAmount = () => {
    if (balance && !balanceLoading) {
      setAmount(balance)
    }
  }

  return (
    <div className="bg-card border border-border rounded-lg p-6">
      <div className="flex items-center space-x-3 mb-6">
        <div className="p-2 bg-primary/10 rounded-lg">
          <Coins className="h-6 w-6 text-primary" />
        </div>
        <div>
          <h2 className="text-2xl font-bold text-card-foreground">Stake SHIP Tokens</h2>
          <p className="text-card-foreground/70">Earn rewards from multiple token sources</p>
        </div>
      </div>

      <div className="space-y-6">
        {/* Amount Input */}
        <div>
          <label className="block text-sm font-medium text-card-foreground mb-2">
            Stake Amount
          </label>
          <div className="relative">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="w-full px-4 py-3 bg-input border border-border rounded-lg text-card-foreground placeholder-card-foreground/50 focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"
            />
            <div className="absolute right-3 top-3 flex items-center space-x-2">
              <span className="text-card-foreground/70 text-sm">SHIP</span>
              <button 
                onClick={setMaxAmount}
                disabled={!isConnected || balanceLoading}
                className="text-primary text-sm hover:text-primary/80 transition-colors disabled:opacity-50"
              >
                MAX
              </button>
            </div>
          </div>
          <div className="flex justify-between mt-2 text-sm">
            <span className="text-card-foreground/60">
              Available: {balanceLoading ? 'Loading...' : `${parseFloat(balance).toFixed(2)} SHIP`}
            </span>
            <span className="text-card-foreground/60">≈ ${(parseFloat(balance) * 0.1).toFixed(2)} USD</span>
          </div>
        </div>

        {/* Lock Period Selection */}
        <div>
          <label className="block text-sm font-medium text-card-foreground mb-3">
            Lock Period & Multiplier
          </label>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {lockOptions.map((option) => (
              <button
                key={option.weeks}
                onClick={() => setLockPeriod(option.weeks)}
                className={`p-4 border rounded-lg transition-all ${
                  lockPeriod === option.weeks
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border text-card-foreground hover:border-primary/50'
                }`}
              >
                <div className="text-center">
                  <div className="font-semibold">{option.label}</div>
                  <div className="text-sm opacity-80">{option.multiplier}</div>
                </div>
              </button>
            ))}
          </div>
          
          <div className="mt-3 p-3 bg-accent/10 border border-accent/20 rounded-lg">
            <div className="flex items-start space-x-2">
              <Info className="h-4 w-4 text-accent mt-0.5 flex-shrink-0" />
              <div className="text-sm text-card-foreground/80">
                <strong>Longer locks = Higher rewards:</strong> Lock periods increase your staking multiplier, 
                earning you a larger share of weekly emissions and multi-token revenue.
              </div>
            </div>
          </div>
        </div>

        {/* Rewards Estimation */}
        <div className="bg-secondary/20 border border-secondary rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-3">
            <Zap className="h-5 w-5 text-accent" />
            <span className="font-semibold text-card-foreground">Estimated Weekly Rewards</span>
          </div>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <div className="text-card-foreground/60">SHIP Emissions:</div>
              <div className="font-semibold text-card-foreground">{estimatedRewards} SHIP</div>
            </div>
            <div>
              <div className="text-card-foreground/60">Multi-Token Revenue:</div>
              <div className="font-semibold text-card-foreground">Variable</div>
            </div>
          </div>
          <div className="mt-3 text-xs text-card-foreground/60">
            * Estimates based on current epoch data and your selected multiplier
          </div>
        </div>

        {/* Error Display */}
        {stakeError && (
          <div className="p-3 bg-error/10 border border-error/20 rounded-lg">
            <p className="text-error text-sm">
              Error: {(stakeError as Error)?.message || 'Transaction failed'}
            </p>
          </div>
        )}

        {!isConnected ? (
          <div className="text-center">
            <ConnectWallet />
          </div>
        ) : (
          /* Action Buttons */
          <div className="flex gap-3">
            <button
              onClick={handleStake}
              disabled={!amount || parseFloat(amount) <= 0 || isStaking || parseFloat(amount) > parseFloat(balance)}
              className="flex-1 flex items-center justify-center space-x-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
            >
              {isStaking ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-2 border-primary-foreground border-t-transparent"></div>
                  <span>Staking...</span>
                </>
              ) : (
                <>
                  <Lock className="h-4 w-4" />
                  <span>Stake SHIP</span>
                </>
              )}
            </button>
          
            <button 
              className="px-6 py-3 bg-secondary text-secondary-foreground border border-border rounded-lg hover:bg-secondary/80 transition-colors font-semibold"
              onClick={() => {
                setAmount('')
                setLockPeriod('1')
              }}
            >
              Reset
            </button>
          </div>
        )}

        {/* Additional Info */}
        <div className="text-xs text-card-foreground/60 space-y-1">
          <p>• Staked tokens cannot be withdrawn before the lock period ends</p>
          <p>• Rewards unlock linearly over each weekly epoch (0% → 100%)</p>
          <p>• Multi-token revenue is distributed in original tokens (no conversion)</p>
        </div>
      </div>
    </div>
  )
}