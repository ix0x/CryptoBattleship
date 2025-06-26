'use client'

import { useState } from 'react'
import { ArrowLeft, Coins, Lock, TrendingUp, Timer } from 'lucide-react'
import Link from 'next/link'
import StakeForm from '@/components/StakeForm'
import EpochProgress from '@/components/EpochProgress'
import RewardsPanel from '@/components/RewardsPanel'
import LinearUnlockProgress from '@/components/LinearUnlockProgress'

export default function StakePage() {
  const [selectedTab, setSelectedTab] = useState<'stake' | 'rewards' | 'epoch'>('stake')

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
              <h1 className="text-2xl font-bold text-foreground">Staking Dashboard</h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-foreground/80">
                Connected: <span className="text-primary font-mono">0x1234...5678</span>
              </div>
              <button className="px-4 py-2 bg-secondary text-secondary-foreground rounded-lg hover:bg-secondary/80 transition-colors">
                Disconnect
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        {/* Tab Navigation */}
        <div className="flex space-x-1 bg-card/30 rounded-lg p-1 mb-8 max-w-md">
          <button
            onClick={() => setSelectedTab('stake')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-md transition-colors flex-1 justify-center ${
              selectedTab === 'stake' 
                ? 'bg-primary text-primary-foreground' 
                : 'text-foreground/70 hover:text-foreground'
            }`}
          >
            <Coins className="h-4 w-4" />
            <span>Stake</span>
          </button>
          <button
            onClick={() => setSelectedTab('rewards')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-md transition-colors flex-1 justify-center ${
              selectedTab === 'rewards' 
                ? 'bg-primary text-primary-foreground' 
                : 'text-foreground/70 hover:text-foreground'
            }`}
          >
            <TrendingUp className="h-4 w-4" />
            <span>Rewards</span>
          </button>
          <button
            onClick={() => setSelectedTab('epoch')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-md transition-colors flex-1 justify-center ${
              selectedTab === 'epoch' 
                ? 'bg-primary text-primary-foreground' 
                : 'text-foreground/70 hover:text-foreground'
            }`}
          >
            <Timer className="h-4 w-4" />
            <span>Epochs</span>
          </button>
        </div>

        {/* Content based on selected tab */}
        {selectedTab === 'stake' && (
          <div className="grid lg:grid-cols-3 gap-8">
            <div className="lg:col-span-2">
              <StakeForm />
            </div>
            <div className="space-y-6">
              {/* Current Stakes Summary */}
              <div className="bg-card border border-border rounded-lg p-6">
                <h3 className="text-xl font-semibold text-card-foreground mb-4 flex items-center">
                  <Lock className="h-5 w-5 mr-2 text-accent" />
                  Your Stakes
                </h3>
                <div className="space-y-4">
                  <div className="flex justify-between">
                    <span className="text-card-foreground/80">Total Staked:</span>
                    <span className="font-semibold text-card-foreground">10,000 SHIP</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-card-foreground/80">Weighted Stake:</span>
                    <span className="font-semibold text-card-foreground">15,000 SHIP</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-card-foreground/80">Active Stakes:</span>
                    <span className="font-semibold text-card-foreground">3</span>
                  </div>
                  <div className="border-t border-border pt-4">
                    <div className="text-sm text-card-foreground/60 mb-2">Current Multiplier</div>
                    <div className="text-2xl font-bold text-accent">1.5x</div>
                  </div>
                </div>
              </div>

              {/* Linear Unlock Progress */}
              <LinearUnlockProgress />
            </div>
          </div>
        )}

        {selectedTab === 'rewards' && (
          <div>
            <RewardsPanel />
          </div>
        )}

        {selectedTab === 'epoch' && (
          <div>
            <EpochProgress />
          </div>
        )}
      </main>
    </div>
  )
}