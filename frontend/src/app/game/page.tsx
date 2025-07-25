'use client'

import { useState } from 'react'
import { ArrowLeft } from 'lucide-react'
import Link from 'next/link'
import { useAccount } from 'wagmi'
import ConnectWallet from '@/components/ConnectWallet'
import GameLobby from '@/components/game/GameLobby'
import FleetSetup from '@/components/game/FleetSetup'
import ShipPlacement from '@/components/game/ShipPlacement'
import BattleInterface from '@/components/game/BattleInterface'
import { useGameState } from '@/hooks/useGameState'

export type GamePhase = 'lobby' | 'fleet-setup' | 'ship-placement' | 'battle' | 'ended'

export default function GamePage() {
  const { isConnected } = useAccount()
  const { currentGameId, gamePhase, gameInfo } = useGameState()

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-background">
        <header className="border-b border-border bg-card/50 backdrop-blur">
          <div className="container mx-auto px-4 py-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <Link href="/" className="flex items-center space-x-2 text-foreground hover:text-primary transition-colors">
                  <ArrowLeft className="h-5 w-5" />
                  <span>Back to Home</span>
                </Link>
                <div className="h-6 w-px bg-border"></div>
                <h1 className="text-2xl font-bold text-foreground">Battleship Game</h1>
              </div>
            </div>
          </div>
        </header>

        <main className="container mx-auto px-4 py-8">
          <div className="text-center py-12">
            <div className="text-6xl mb-4">🔌</div>
            <h3 className="text-xl font-semibold text-foreground mb-2">Connect Your Wallet</h3>
            <p className="text-foreground/70 mb-6">Connect your wallet to start playing CryptoBattleship</p>
            <ConnectWallet />
          </div>
        </main>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border bg-card/50 backdrop-blur">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/" className="flex items-center space-x-2 text-foreground hover:text-primary transition-colors">
                <ArrowLeft className="h-5 w-5" />
                <span>Back to Home</span>
              </Link>
              <div className="h-6 w-px bg-border"></div>
              <h1 className="text-2xl font-bold text-foreground">
                {gamePhase === 'lobby' && 'Game Lobby'}
                {gamePhase === 'fleet-setup' && 'Fleet Setup'}
                {gamePhase === 'ship-placement' && 'Ship Placement'}
                {gamePhase === 'battle' && 'Battle'}
                {gamePhase === 'ended' && 'Game Over'}
              </h1>
            </div>
            {currentGameId && (
              <div className="text-sm text-foreground/80">
                Game ID: <span className="text-primary font-mono">#{currentGameId}</span>
              </div>
            )}
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        {gamePhase === 'lobby' && <GameLobby />}
        {gamePhase === 'fleet-setup' && <FleetSetup gameId={currentGameId!} />}
        {gamePhase === 'ship-placement' && <ShipPlacement gameId={currentGameId!} />}
        {gamePhase === 'battle' && <BattleInterface gameId={currentGameId!} />}
        {gamePhase === 'ended' && (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">🏆</div>
            <h3 className="text-xl font-semibold text-foreground mb-2">Game Complete!</h3>
            <p className="text-foreground/70 mb-6">
              {gameInfo?.winner ? `Winner: ${gameInfo.winner}` : 'Game ended'}
            </p>
            <button 
              onClick={() => window.location.reload()}
              className="px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold"
            >
              Play Again
            </button>
          </div>
        )}
      </main>
    </div>
  )
}