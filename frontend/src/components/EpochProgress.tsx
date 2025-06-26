'use client'

import { useState, useEffect } from 'react'
import { Calendar, Clock, TrendingUp, Users } from 'lucide-react'

interface EpochData {
  current: number
  startTime: Date
  endTime: Date
  totalEmissions: string
  totalStakers: number
  avgMultiplier: string
  revenueBonus: string
}

export default function EpochProgress() {
  const [epochData] = useState<EpochData>({
    current: 42,
    startTime: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
    endTime: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000), // 4 days from now
    totalEmissions: '125,000',
    totalStakers: 1247,
    avgMultiplier: '1.3',
    revenueBonus: '15'
  })
  
  const [timeRemaining, setTimeRemaining] = useState('')
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    const updateTimer = () => {
      const now = new Date()
      const total = epochData.endTime.getTime() - epochData.startTime.getTime()
      const elapsed = now.getTime() - epochData.startTime.getTime()
      const remaining = epochData.endTime.getTime() - now.getTime()
      
      // Calculate progress (0-100)
      const progressPercent = Math.max(0, Math.min(100, (elapsed / total) * 100))
      setProgress(progressPercent)
      
      // Format time remaining
      if (remaining > 0) {
        const days = Math.floor(remaining / (24 * 60 * 60 * 1000))
        const hours = Math.floor((remaining % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000))
        const minutes = Math.floor((remaining % (60 * 60 * 1000)) / (60 * 1000))
        
        if (days > 0) {
          setTimeRemaining(`${days}d ${hours}h ${minutes}m`)
        } else if (hours > 0) {
          setTimeRemaining(`${hours}h ${minutes}m`)
        } else {
          setTimeRemaining(`${minutes}m`)
        }
      } else {
        setTimeRemaining('Epoch ended')
      }
    }
    
    updateTimer()
    const interval = setInterval(updateTimer, 60000) // Update every minute
    
    return () => clearInterval(interval)
  }, [epochData])

  return (
    <div className="space-y-6">
      {/* Current Epoch Header */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-accent/10 rounded-lg">
              <Calendar className="h-6 w-6 text-accent" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-card-foreground">Epoch {epochData.current}</h2>
              <p className="text-card-foreground/70">Weekly reward distribution cycle</p>
            </div>
          </div>
          <div className="text-right">
            <div className="text-2xl font-bold text-accent">{timeRemaining}</div>
            <div className="text-sm text-card-foreground/60">remaining</div>
          </div>
        </div>

        {/* Progress Bar */}
        <div className="mb-6">
          <div className="flex justify-between text-sm text-card-foreground/80 mb-2">
            <span>Epoch Progress</span>
            <span>{progress.toFixed(1)}% complete</span>
          </div>
          <div className="w-full bg-secondary/20 rounded-full h-3">
            <div 
              className="bg-gradient-to-r from-accent to-primary h-3 rounded-full transition-all duration-300 ease-out"
              style={{ width: `${progress}%` }}
            />
          </div>
          <div className="flex justify-between text-xs text-card-foreground/60 mt-1">
            <span>{epochData.startTime.toLocaleDateString()}</span>
            <span>{epochData.endTime.toLocaleDateString()}</span>
          </div>
        </div>

        {/* Epoch Stats Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-secondary/10 rounded-lg p-4">
            <div className="flex items-center space-x-2 mb-2">
              <TrendingUp className="h-4 w-4 text-accent" />
              <span className="text-sm text-card-foreground/80">Total Emissions</span>
            </div>
            <div className="text-lg font-bold text-card-foreground">{epochData.totalEmissions} SHIP</div>
          </div>
          
          <div className="bg-secondary/10 rounded-lg p-4">
            <div className="flex items-center space-x-2 mb-2">
              <Users className="h-4 w-4 text-accent" />
              <span className="text-sm text-card-foreground/80">Active Stakers</span>
            </div>
            <div className="text-lg font-bold text-card-foreground">{epochData.totalStakers.toLocaleString()}</div>
          </div>
          
          <div className="bg-secondary/10 rounded-lg p-4">
            <div className="flex items-center space-x-2 mb-2">
              <Clock className="h-4 w-4 text-accent" />
              <span className="text-sm text-card-foreground/80">Avg Multiplier</span>
            </div>
            <div className="text-lg font-bold text-card-foreground">{epochData.avgMultiplier}x</div>
          </div>
          
          <div className="bg-secondary/10 rounded-lg p-4">
            <div className="flex items-center space-x-2 mb-2">
              <TrendingUp className="h-4 w-4 text-accent" />
              <span className="text-sm text-card-foreground/80">Revenue Bonus</span>
            </div>
            <div className="text-lg font-bold text-card-foreground">+{epochData.revenueBonus}%</div>
          </div>
        </div>
      </div>

      {/* Linear Unlock Explanation */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-semibold text-card-foreground mb-4">Linear Unlock Schedule</h3>
        <div className="space-y-4">
          <p className="text-card-foreground/80">
            Rewards unlock gradually throughout the epoch, starting at 0% and reaching 100% by the end of the week.
          </p>
          
          <div className="grid md:grid-cols-3 gap-4 text-sm">
            <div className="bg-secondary/10 rounded-lg p-3">
              <div className="text-accent font-semibold mb-1">Day 1-2</div>
              <div className="text-card-foreground/80">0% - 28% unlocked</div>
            </div>
            <div className="bg-secondary/10 rounded-lg p-3">
              <div className="text-accent font-semibold mb-1">Day 3-5</div>
              <div className="text-card-foreground/80">28% - 71% unlocked</div>
            </div>
            <div className="bg-secondary/10 rounded-lg p-3">
              <div className="text-accent font-semibold mb-1">Day 6-7</div>
              <div className="text-card-foreground/80">71% - 100% unlocked</div>
            </div>
          </div>
          
          <div className="bg-accent/10 border border-accent/20 rounded-lg p-4 mt-4">
            <p className="text-sm text-card-foreground/80">
              <strong>Pro tip:</strong> You can claim partial rewards at any time during the epoch. 
              Rewards continue unlocking even after claiming, so you can claim multiple times per week.
            </p>
          </div>
        </div>
      </div>

      {/* Recent Epochs */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-semibold text-card-foreground mb-4">Recent Epochs</h3>
        <div className="space-y-3">
          {[
            { epoch: 41, emissions: '118,500', bonus: '12%', status: 'Completed' },
            { epoch: 40, emissions: '115,200', bonus: '8%', status: 'Completed' },
            { epoch: 39, emissions: '121,800', bonus: '18%', status: 'Completed' },
          ].map((epoch) => (
            <div key={epoch.epoch} className="flex items-center justify-between p-3 bg-secondary/5 rounded-lg">
              <div className="flex items-center space-x-4">
                <div className="text-card-foreground font-semibold">Epoch {epoch.epoch}</div>
                <div className="text-sm text-card-foreground/70">{epoch.emissions} SHIP</div>
                <div className="text-sm text-accent">+{epoch.bonus} revenue bonus</div>
              </div>
              <div className="text-sm text-success bg-success/10 px-2 py-1 rounded">
                {epoch.status}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}