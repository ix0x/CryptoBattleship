'use client'

import { useState, useEffect } from 'react'
import { Clock, TrendingUp, Award, Calendar } from 'lucide-react'
import { useProtocolStats } from '@/hooks/useProtocolStats'

export default function EpochProgress() {
  const { currentEpoch, epochProgress, weeklyEmissions, isLoading } = useProtocolStats()
  const [timeLeft, setTimeLeft] = useState<string>('')

  // Update countdown timer
  useEffect(() => {
    if (!epochProgress?.timeLeft) return

    const updateTimer = () => {
      const seconds = epochProgress.timeLeft
      const days = Math.floor(seconds / 86400)
      const hours = Math.floor((seconds % 86400) / 3600)
      const minutes = Math.floor((seconds % 3600) / 60)
      const remainingSeconds = seconds % 60

      if (days > 0) {
        setTimeLeft(`${days}d ${hours}h ${minutes}m`)
      } else if (hours > 0) {
        setTimeLeft(`${hours}h ${minutes}m ${remainingSeconds}s`)
      } else if (minutes > 0) {
        setTimeLeft(`${minutes}m ${remainingSeconds}s`)
      } else {
        setTimeLeft(`${remainingSeconds}s`)
      }
    }

    updateTimer()
    const interval = setInterval(updateTimer, 1000)
    return () => clearInterval(interval)
  }, [epochProgress?.timeLeft])

  if (isLoading || !epochProgress) {
    return (
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-4">
          <div className="animate-pulse w-8 h-8 bg-secondary/20 rounded-lg"></div>
          <div className="animate-pulse w-32 h-6 bg-secondary/20 rounded"></div>
        </div>
        <div className="animate-pulse w-full h-4 bg-secondary/20 rounded mb-4"></div>
        <div className="grid grid-cols-3 gap-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="animate-pulse">
              <div className="w-full h-4 bg-secondary/20 rounded mb-2"></div>
              <div className="w-3/4 h-3 bg-secondary/20 rounded"></div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  return (
    <div className="bg-card border border-border rounded-lg p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-primary/10 rounded-lg">
            <Clock className="h-6 w-6 text-primary" />
          </div>
          <div>
            <h3 className="text-xl font-bold text-card-foreground">Epoch Progress</h3>
            <p className="text-card-foreground/70">Current epoch #{currentEpoch}</p>
          </div>
        </div>
        
        <div className="text-right">
          <div className="text-2xl font-bold text-accent">{epochProgress.progress.toFixed(1)}%</div>
          <div className="text-sm text-card-foreground/70">Complete</div>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm text-card-foreground/70">Epoch Progress</span>
          <span className="text-sm font-medium text-card-foreground">{timeLeft} remaining</span>
        </div>
        
        <div className="w-full bg-secondary/20 rounded-full h-3 overflow-hidden">
          <div 
            className="h-full bg-gradient-to-r from-primary to-accent transition-all duration-1000 ease-out"
            style={{ width: `${epochProgress.progress}%` }}
          >
            <div className="h-full bg-white/20 animate-pulse"></div>
          </div>
        </div>
        
        <div className="flex justify-between text-xs text-card-foreground/60 mt-1">
          <span>Start</span>
          <span>Week Complete</span>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid md:grid-cols-3 gap-4 mb-4">
        <div className="text-center p-3 bg-secondary/10 rounded-lg">
          <div className="flex items-center justify-center mb-2">
            <Calendar className="h-4 w-4 text-accent mr-1" />
            <span className="text-sm text-card-foreground/70">Time Left</span>
          </div>
          <div className="font-bold text-card-foreground">{timeLeft}</div>
        </div>
        
        <div className="text-center p-3 bg-secondary/10 rounded-lg">
          <div className="flex items-center justify-center mb-2">
            <TrendingUp className="h-4 w-4 text-accent mr-1" />
            <span className="text-sm text-card-foreground/70">Emissions</span>
          </div>
          <div className="font-bold text-card-foreground">
            {parseFloat(weeklyEmissions).toFixed(0)} SHIP
          </div>
        </div>
        
        <div className="text-center p-3 bg-secondary/10 rounded-lg">
          <div className="flex items-center justify-center mb-2">
            <Award className="h-4 w-4 text-accent mr-1" />
            <span className="text-sm text-card-foreground/70">Next Epoch</span>
          </div>
          <div className="font-bold text-card-foreground">#{currentEpoch + 1}</div>
        </div>
      </div>

      {/* Epoch Status */}
      <div className={`p-3 rounded-lg border ${
        epochProgress.isComplete 
          ? 'bg-green-50 border-green-200' 
          : epochProgress.progress > 75
            ? 'bg-yellow-50 border-yellow-200'
            : 'bg-blue-50 border-blue-200'
      }`}>
        <div className="flex items-center space-x-2">
          <div className={`w-2 h-2 rounded-full ${
            epochProgress.isComplete
              ? 'bg-green-500'
              : epochProgress.progress > 75
                ? 'bg-yellow-500'
                : 'bg-blue-500 animate-pulse'
          }`}></div>
          <span className={`text-sm font-medium ${
            epochProgress.isComplete
              ? 'text-green-700'
              : epochProgress.progress > 75
                ? 'text-yellow-700'
                : 'text-blue-700'
          }`}>
            {epochProgress.isComplete
              ? 'Epoch complete - rewards unlocked!'
              : epochProgress.progress > 75
                ? 'Epoch ending soon - rewards will unlock'
                : 'Epoch in progress - earning rewards'
            }
          </span>
        </div>
      </div>

      {/* Additional Info */}
      <div className="mt-4 text-xs text-card-foreground/60 space-y-1">
        <p>• Epochs last 1 week (604,800 seconds)</p>
        <p>• Rewards unlock linearly throughout each epoch</p>
        <p>• Staking multipliers reset at the start of each new epoch</p>
      </div>
    </div>
  )
}