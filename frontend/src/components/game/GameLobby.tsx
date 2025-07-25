'use client'

import { useState } from 'react'
import { Users, Coins, Play, Plus } from 'lucide-react'
import { useContractRead, useContractWrite } from '@/hooks/useContract'
import { formatEther } from 'viem'

const GAME_SIZES = [
  { key: 0, name: 'Shrimp', description: 'Quick match for beginners' },
  { key: 1, name: 'Fish', description: 'Standard competitive game' },
  { key: 2, name: 'Shark', description: 'High stakes battle' },
  { key: 3, name: 'Whale', description: 'Ultimate challenge' },
] as const

export default function GameLobby() {
  const [selectedGameSize, setSelectedGameSize] = useState(0)
  const [showCreateGame, setShowCreateGame] = useState(false)

  // Get ante amounts for each game size
  const { data: shrimpAnte } = useContractRead('BattleshipGame', 'anteAmounts', [0])
  const { data: fishAnte } = useContractRead('BattleshipGame', 'anteAmounts', [1])
  const { data: sharkAnte } = useContractRead('BattleshipGame', 'anteAmounts', [2])
  const { data: whaleAnte } = useContractRead('BattleshipGame', 'anteAmounts', [3])

  const antes = [shrimpAnte, fishAnte, sharkAnte, whaleAnte]

  // Get list of waiting games (simplified - in production would need events or subgraph)
  const { data: nextGameId } = useContractRead('GameState', 'nextGameId', [])

  // Contract interactions
  const { writeContract: createGame, isPending: isCreating, error: createError } = useContractWrite('BattleshipGame')
  const { writeContract: joinGame, isPending: isJoining, error: joinError } = useContractWrite('BattleshipGame')

  const handleCreateGame = async () => {
    try {
      await createGame('createGame', [selectedGameSize], {
        value: antes[selectedGameSize] || 0n
      })
    } catch (error) {
      console.error('Failed to create game:', error)
    }
  }

  const handleJoinGame = async (gameId: number) => {
    try {
      const ante = antes[selectedGameSize] || 0n
      await joinGame('joinGame', [gameId], {
        value: ante
      })
    } catch (error) {
      console.error('Failed to join game:', error)
    }
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      {/* Create Game Section */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-primary/10 rounded-lg">
              <Plus className="h-6 w-6 text-primary" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-card-foreground">Create New Game</h2>
              <p className="text-card-foreground/70">Choose your game size and start a match</p>
            </div>
          </div>
        </div>

        {/* Game Size Selection */}
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {GAME_SIZES.map((size, index) => (
            <button
              key={size.key}
              onClick={() => setSelectedGameSize(size.key)}
              className={`p-4 border rounded-lg transition-all text-left ${
                selectedGameSize === size.key
                  ? 'border-primary bg-primary/10 text-primary'
                  : 'border-border text-card-foreground hover:border-primary/50'
              }`}
            >
              <div className="font-semibold mb-1">{size.name}</div>
              <div className="text-sm opacity-80 mb-2">{size.description}</div>
              <div className="text-xs font-mono">
                Ante: {antes[index] ? formatEther(antes[index] as bigint) : '0'} S
              </div>
            </button>
          ))}
        </div>

        {/* Create Game Button */}
        <div className="space-y-4">
          {createError && (
            <div className="p-3 bg-error/10 border border-error/20 rounded-lg">
              <p className="text-error text-sm">
                Error: {(createError as Error)?.message || 'Failed to create game'}
              </p>
            </div>
          )}

          <button
            onClick={handleCreateGame}
            disabled={isCreating}
            className="w-full flex items-center justify-center space-x-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
          >
            {isCreating ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-2 border-primary-foreground border-t-transparent"></div>
                <span>Creating Game...</span>
              </>
            ) : (
              <>
                <Play className="h-4 w-4" />
                <span>Create {GAME_SIZES[selectedGameSize].name} Game</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Available Games Section */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-6">
          <div className="p-2 bg-accent/10 rounded-lg">
            <Users className="h-6 w-6 text-accent" />
          </div>
          <div>
            <h2 className="text-2xl font-bold text-card-foreground">Join Existing Game</h2>
            <p className="text-card-foreground/70">Join a game that's waiting for players</p>
          </div>
        </div>

        {/* Placeholder for available games - would need events/subgraph in production */}
        <div className="space-y-3">
          {/* Mock waiting games */}
          <div className="text-center py-8">
            <div className="text-4xl mb-3">⚓</div>
            <h3 className="text-lg font-semibold text-card-foreground mb-2">No Games Available</h3>
            <p className="text-card-foreground/70 text-sm">Create a new game to start playing!</p>
          </div>
        </div>

        {joinError && (
          <div className="p-3 bg-error/10 border border-error/20 rounded-lg mt-4">
            <p className="text-error text-sm">
              Error: {(joinError as Error)?.message || 'Failed to join game'}
            </p>
          </div>
        )}
      </div>

      {/* Game Rules Section */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-bold text-card-foreground mb-4">How to Play</h3>
        <div className="grid md:grid-cols-2 gap-6 text-sm text-card-foreground/80">
          <div>
            <h4 className="font-semibold text-card-foreground mb-2">1. Fleet Setup</h4>
            <p>Choose your ship NFT, captain, crew members, and action cards for the battle.</p>
          </div>
          <div>
            <h4 className="font-semibold text-card-foreground mb-2">2. Ship Placement</h4>
            <p>Place your 5 ships strategically on the 10x10 grid. Ships cannot overlap or touch.</p>
          </div>
          <div>
            <h4 className="font-semibold text-card-foreground mb-2">3. Battle Phase</h4>
            <p>Take turns attacking coordinates on your opponent's grid. Use action cards for special abilities.</p>
          </div>
          <div>
            <h4 className="font-semibold text-card-foreground mb-2">4. Victory</h4>
            <p>First player to sink all enemy ships wins the ante and earns credits!</p>
          </div>
        </div>
      </div>
    </div>
  )
}