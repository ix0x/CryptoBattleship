'use client'

import { useState, useEffect } from 'react'
import { Clock, TrendingUp, Unlock } from 'lucide-react'

interface UnlockData {
  totalRewards: number
  unlockedAmount: number
  nextUnlockIn: string
  unlockRate: number // tokens per hour
}

export default function LinearUnlockProgress() {
  const [unlockData, setUnlockData] = useState<UnlockData>({
    totalRewards: 1250,
    unlockedAmount: 0,
    nextUnlockIn: '',
    unlockRate: 7.44 // 1250 tokens / 168 hours
  })

  const [, setCurrentTime] = useState(new Date())

  useEffect(() => {
    const updateProgress = () => {
      const now = new Date()
      setCurrentTime(now)
      
      // Simulate epoch start (3 days ago)
      const epochStart = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000)
      // Calculate epoch progress
      
      // Calculate elapsed time in hours
      const elapsedHours = (now.getTime() - epochStart.getTime()) / (1000 * 60 * 60)
      const totalHours = 168 // 7 days * 24 hours
      
      // Calculate unlocked amount (linear)
      const progress = Math.max(0, Math.min(1, elapsedHours / totalHours))
      const newUnlockedAmount = unlockData.totalRewards * progress
      
      // Calculate time to next hour unlock
      const minutesToNextHour = 60 - now.getMinutes()
      const secondsToNextHour = 60 - now.getSeconds()
      
      setUnlockData(prev => ({
        ...prev,
        unlockedAmount: newUnlockedAmount,
        nextUnlockIn: `${minutesToNextHour - 1}m ${secondsToNextHour}s`
      }))
    }

    updateProgress()
    const interval = setInterval(updateProgress, 1000) // Update every second
    
    return () => clearInterval(interval)
  }, [unlockData.totalRewards])

  const progressPercentage = (unlockData.unlockedAmount / unlockData.totalRewards) * 100
  const remainingRewards = unlockData.totalRewards - unlockData.unlockedAmount

  return (
    <div className="bg-card border border-border rounded-lg p-6">
      <div className="flex items-center space-x-3 mb-4">
        <div className="p-2 bg-accent/10 rounded-lg">
          <Unlock className="h-5 w-5 text-accent" />
        </div>
        <h3 className="text-lg font-semibold text-card-foreground">Linear Unlock Progress</h3>
      </div>

      {/* Progress Overview */}
      <div className="space-y-4">
        <div className="flex justify-between items-center">
          <span className="text-card-foreground/80">Current Epoch Rewards</span>
          <span className="font-semibold text-card-foreground">{unlockData.totalRewards} SHIP</span>
        </div>

        {/* Progress Bar */}
        <div>
          <div className="flex justify-between text-sm text-card-foreground/80 mb-2">
            <span>Unlocked</span>
            <span>{progressPercentage.toFixed(1)}%</span>
          </div>
          <div className="w-full bg-secondary/20 rounded-full h-4 relative overflow-hidden">
            <div 
              className="bg-gradient-to-r from-accent to-primary h-4 rounded-full transition-all duration-1000 ease-out relative"
              style={{ width: `${progressPercentage}%` }}
            >
              {/* Animated shimmer effect */}
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent animate-pulse" />
            </div>
          </div>
        </div>

        {/* Unlock Details */}
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <div className="text-card-foreground/60 mb-1">Available to Claim</div>
            <div className="font-semibold text-success text-lg">
              {unlockData.unlockedAmount.toFixed(2)} SHIP
            </div>
          </div>
          <div>
            <div className="text-card-foreground/60 mb-1">Still Locked</div>
            <div className="font-semibold text-card-foreground text-lg">
              {remainingRewards.toFixed(2)} SHIP
            </div>
          </div>
        </div>

        {/* Unlock Rate */}
        <div className="bg-secondary/10 rounded-lg p-3">
          <div className="flex items-center space-x-2 mb-2">
            <TrendingUp className="h-4 w-4 text-accent" />
            <span className="text-sm font-medium text-card-foreground">Unlock Rate</span>
          </div>
          <div className="text-card-foreground/80 text-sm">
            <div>{unlockData.unlockRate.toFixed(2)} SHIP per hour</div>
            <div>{(unlockData.unlockRate * 24).toFixed(0)} SHIP per day</div>
          </div>
        </div>

        {/* Next Unlock Timer */}
        <div className="bg-accent/10 border border-accent/20 rounded-lg p-3">
          <div className="flex items-center space-x-2 mb-1">
            <Clock className="h-4 w-4 text-accent" />
            <span className="text-sm font-medium text-card-foreground">Next Unlock</span>
          </div>
          <div className="text-card-foreground/80 text-sm">
            <div>+{unlockData.unlockRate.toFixed(2)} SHIP in {unlockData.nextUnlockIn}</div>
          </div>
        </div>

        {/* Claim Button */}
        <button 
          className="w-full px-4 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
          disabled={unlockData.unlockedAmount < 0.01}
        >
          {unlockData.unlockedAmount >= 0.01 
            ? `Claim ${unlockData.unlockedAmount.toFixed(2)} SHIP`
            : 'No rewards to claim yet'
          }
        </button>

        {/* Info Text */}
        <div className="text-xs text-card-foreground/60">
          <p>• Rewards unlock continuously throughout the epoch</p>
          <p>• You can claim partial rewards at any time</p>
          <p>• 30% available immediately, 70% vests over 1 week</p>
        </div>
      </div>
    </div>
  )
}