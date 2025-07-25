'use client'

import { Anchor, Coins, Shield, Target, TrendingUp } from 'lucide-react'
import Link from 'next/link'
import PlaceholderImage from '@/components/PlaceholderImage'
import ConnectWallet from '@/components/ConnectWallet'
import LootboxPanel from '@/components/LootboxPanel'
import { useProtocolStats } from '@/hooks/useProtocolStats'

export default function Home() {
  const { totalStaked, currentEpoch, weeklyEmissions, isLoading } = useProtocolStats()
  
  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Anchor className="h-8 w-8 text-primary" />
              <h1 className="text-2xl font-bold text-foreground">CryptoBattleship</h1>
            </div>
            <div className="flex items-center space-x-4">
              <ConnectWallet />
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        {/* Hero Section */}
        <section className="text-center mb-12">
          <h2 className="text-4xl font-bold text-foreground mb-4">
            Strategic Naval Combat on the Blockchain
          </h2>
          <p className="text-lg text-foreground/80 max-w-2xl mx-auto mb-8">
            Stake SHIP tokens, earn multi-token rewards, and dominate the seas in this decentralized battleship game.
          </p>
          
          {/* Hero Image Placeholder */}
          <div className="mb-8">
            <PlaceholderImage 
              width={600} 
              height={300} 
              text="Battleship Game Scene"
              className="mx-auto rounded-lg border border-border"
            />
          </div>
        </section>

        {/* Feature Cards */}
        <section className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
          <div className="bg-card border border-border rounded-lg p-6 hover:border-primary/50 transition-colors">
            <div className="flex items-center space-x-3 mb-4">
              <Coins className="h-8 w-8 text-accent" />
              <h3 className="text-xl font-semibold text-card-foreground">Stake & Earn</h3>
            </div>
            <p className="text-card-foreground/80">
              Stake SHIP tokens and earn rewards in multiple tokens including ETH, USDC, and more.
            </p>
          </div>

          <div className="bg-card border border-border rounded-lg p-6 hover:border-primary/50 transition-colors">
            <div className="flex items-center space-x-3 mb-4">
              <TrendingUp className="h-8 w-8 text-accent" />
              <h3 className="text-xl font-semibold text-card-foreground">Dynamic Emissions</h3>
            </div>
            <p className="text-card-foreground/80">
              Token emissions adjust based on protocol revenue for sustainable growth.
            </p>
          </div>

          <div className="bg-card border border-border rounded-lg p-6 hover:border-primary/50 transition-colors">
            <div className="flex items-center space-x-3 mb-4">
              <Shield className="h-8 w-8 text-accent" />
              <h3 className="text-xl font-semibold text-card-foreground">NFT Fleet</h3>
            </div>
            <p className="text-card-foreground/80">
              Collect unique ships, captains, and crew with on-chain SVG art.
            </p>
          </div>

          <div className="bg-card border border-border rounded-lg p-6 hover:border-primary/50 transition-colors">
            <div className="flex items-center space-x-3 mb-4">
              <Target className="h-8 w-8 text-accent" />
              <h3 className="text-xl font-semibold text-card-foreground">Strategic Combat</h3>
            </div>
            <p className="text-card-foreground/80">
              Engage in tactical battles and earn credits that convert to SHIP tokens.
            </p>
          </div>
        </section>

        {/* Quick Stats */}
        <section className="bg-card border border-border rounded-lg p-8 mb-12">
          <h3 className="text-2xl font-bold text-card-foreground mb-6 text-center">Protocol Stats</h3>
          <div className="grid md:grid-cols-4 gap-6 text-center">
            <div>
              <div className="text-3xl font-bold text-accent mb-2">
                {isLoading ? '...' : `${parseFloat(totalStaked).toFixed(0)}`}
              </div>
              <div className="text-card-foreground/80">Total Staked (SHIP)</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-accent mb-2">
                {isLoading ? '...' : currentEpoch}
              </div>
              <div className="text-card-foreground/80">Current Epoch</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-accent mb-2">
                {isLoading ? '...' : `${parseFloat(weeklyEmissions).toFixed(0)}`}
              </div>
              <div className="text-card-foreground/80">Weekly Emissions</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-accent mb-2">Live</div>
              <div className="text-card-foreground/80">On Sonic Blaze</div>
            </div>
          </div>
        </section>

        {/* Lootbox Section */}
        <section className="mb-12">
          <div className="text-center mb-8">
            <h3 className="text-2xl font-bold text-foreground mb-4">Build Your Fleet</h3>
            <p className="text-foreground/80">
              Purchase lootboxes to collect ships, captains, crew members, and action cards.
            </p>
          </div>
          <div className="max-w-2xl mx-auto">
            <LootboxPanel />
          </div>
        </section>

        {/* CTA Section */}
        <section className="text-center">
          <h3 className="text-2xl font-bold text-foreground mb-4">Ready to Command Your Fleet?</h3>
          <p className="text-foreground/80 mb-6">
            Connect your wallet to start staking and earning rewards in the CryptoBattleship ecosystem.
          </p>
          <div className="flex gap-4 justify-center flex-wrap">
            <Link href="/game" className="px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold">
              Play Battleship
            </Link>
            <Link href="/stake" className="px-6 py-3 bg-secondary text-secondary-foreground border border-border rounded-lg hover:bg-secondary/80 transition-colors font-semibold">
              Start Staking
            </Link>
            <Link href="/fleet" className="px-6 py-3 bg-secondary text-secondary-foreground border border-border rounded-lg hover:bg-secondary/80 transition-colors font-semibold">
              View Fleet
            </Link>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-border bg-card/30 mt-16">
        <div className="container mx-auto px-4 py-8">
          <div className="text-center text-card-foreground/60">
            <p>&copy; 2024 CryptoBattleship. Built with Next.js and deployed on the blockchain.</p>
          </div>
        </div>
      </footer>
    </div>
  )
}
