'use client'

import { useState, useEffect } from 'react'
import { Target, Zap, Clock, User } from 'lucide-react'
import { useAccount } from 'wagmi'
import { useContractRead, useContractWrite } from '@/hooks/useContract'

interface BattleInterfaceProps {
  gameId: number
}

type CellState = 'unknown' | 'miss' | 'hit' | 'sunk'

export default function BattleInterface({ gameId }: BattleInterfaceProps) {
  const { address } = useAccount()
  const [enemyGrid, setEnemyGrid] = useState<CellState[][]>(
    Array(10).fill(null).map(() => Array(10).fill('unknown'))
  )
  const [selectedCell, setSelectedCell] = useState<{ x: number; y: number } | null>(null)
  const [gameInfo, setGameInfo] = useState<any>(null)

  // Get game info
  const { data: contractGameInfo, refetch: refetchGameInfo } = useContractRead(
    'GameState',
    'games',
    [gameId],
    { watch: true }
  )

  // Get game state data
  const { data: gameStateData } = useContractRead(
    'GameState',
    'gameStates',
    [gameId],
    { watch: true }
  )

  // Contract interactions
  const { writeContract: makeAttack, isPending: isAttacking, error: attackError } = useContractWrite('BattleshipGame')
  const { writeContract: useAction, isPending: isUsingAction, error: actionError } = useContractWrite('BattleshipGame')

  useEffect(() => {
    if (contractGameInfo) {
      setGameInfo(contractGameInfo)
    }
  }, [contractGameInfo])

  const isMyTurn = gameInfo && address && (
    (gameInfo.currentPlayer === 1 && gameInfo.player1.toLowerCase() === address.toLowerCase()) ||
    (gameInfo.currentPlayer === 2 && gameInfo.player2.toLowerCase() === address.toLowerCase())
  )

  const opponent = gameInfo && address ? (
    gameInfo.player1.toLowerCase() === address.toLowerCase() ? gameInfo.player2 : gameInfo.player1
  ) : null

  const handleCellClick = (x: number, y: number) => {
    if (!isMyTurn || isAttacking) return
    setSelectedCell({ x, y })
  }

  const handleAttack = async () => {
    if (!selectedCell || !isMyTurn || isAttacking) return

    try {
      await makeAttack('defaultAttack', [gameId, selectedCell.x, selectedCell.y])
      
      // Update local grid (in production, you'd get this from events)
      setEnemyGrid(prev => {
        const newGrid = prev.map(row => [...row])
        // This would be determined by the contract response/events
        newGrid[selectedCell.y][selectedCell.x] = 'miss' // Placeholder
        return newGrid
      })
      
      setSelectedCell(null)
      refetchGameInfo()
    } catch (error) {
      console.error('Attack failed:', error)
    }
  }

  const getCellColor = (x: number, y: number) => {
    const cell = enemyGrid[y][x]
    const isSelected = selectedCell?.x === x && selectedCell?.y === y
    
    if (isSelected) return 'bg-yellow-300 border-yellow-500'
    
    switch (cell) {
      case 'hit': return 'bg-red-300 border-red-500'
      case 'miss': return 'bg-gray-300 border-gray-500'
      case 'sunk': return 'bg-red-500 border-red-700'
      default: return 'bg-blue-100 hover:bg-blue-200 border-blue-300'
    }
  }

  const getCellSymbol = (x: number, y: number) => {
    const cell = enemyGrid[y][x]
    switch (cell) {
      case 'hit': return '💥'
      case 'miss': return '❌'
      case 'sunk': return '🔥'
      default: return ''
    }
  }

  if (!gameInfo) {
    return (
      <div className="text-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-2 border-primary border-t-transparent mx-auto mb-4"></div>
        <h3 className="text-xl font-semibold text-foreground mb-2">Loading Battle...</h3>
        <p className="text-foreground/70">Preparing the battlefield</p>
      </div>
    )
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      {/* Game Status */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="grid md:grid-cols-3 gap-6">
          <div className="text-center">
            <div className="flex items-center justify-center space-x-2 mb-2">
              <User className="h-5 w-5 text-primary" />
              <span className="font-semibold text-card-foreground">You</span>
            </div>
            <div className="text-sm text-card-foreground/70">
              Ships: {gameStateData ? (gameStateData as any).player1ShipsRemaining || 5 : 5}/5
            </div>
          </div>
          
          <div className="text-center">
            <div className="flex items-center justify-center space-x-2 mb-2">
              <Clock className="h-5 w-5 text-accent" />
              <span className="font-semibold text-card-foreground">
                {isMyTurn ? 'Your Turn' : 'Opponent\'s Turn'}
              </span>
            </div>
            <div className="text-sm text-card-foreground/70">
              Game #{gameId}
            </div>
          </div>
          
          <div className="text-center">
            <div className="flex items-center justify-center space-x-2 mb-2">
              <User className="h-5 w-5 text-secondary" />
              <span className="font-semibold text-card-foreground">Opponent</span>
            </div>
            <div className="text-sm text-card-foreground/70">
              Ships: {gameStateData ? (gameStateData as any).player2ShipsRemaining || 5 : 5}/5
            </div>
            <div className="text-xs text-card-foreground/60 font-mono">
              {opponent ? `${opponent.slice(0, 6)}...${opponent.slice(-4)}` : 'Unknown'}
            </div>
          </div>
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-8">
        {/* Enemy Grid - Attack Target */}
        <div className="lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xl font-bold text-foreground">Enemy Waters</h3>
            {selectedCell && (
              <div className="text-sm text-foreground/70">
                Selected: {String.fromCharCode(65 + selectedCell.x)}{selectedCell.y + 1}
              </div>
            )}
          </div>
          
          <div className="inline-block border-2 border-border rounded-lg overflow-hidden">
            {/* Column headers */}
            <div className="grid grid-cols-11 bg-secondary">
              <div className="w-8 h-8"></div>
              {Array.from({ length: 10 }, (_, i) => (
                <div key={i} className="w-8 h-8 flex items-center justify-center text-xs font-semibold">
                  {String.fromCharCode(65 + i)}
                </div>
              ))}
            </div>
            
            {/* Grid with row headers */}
            {Array.from({ length: 10 }, (_, y) => (
              <div key={y} className="grid grid-cols-11">
                <div className="w-8 h-8 bg-secondary flex items-center justify-center text-xs font-semibold">
                  {y + 1}
                </div>
                {Array.from({ length: 10 }, (_, x) => (
                  <button
                    key={`${x}-${y}`}
                    className={`w-8 h-8 border border-border text-xs font-bold ${getCellColor(x, y)} transition-all disabled:cursor-not-allowed ${
                      isMyTurn && !isAttacking ? 'hover:scale-105' : ''
                    }`}
                    onClick={() => handleCellClick(x, y)}
                    disabled={!isMyTurn || isAttacking || enemyGrid[y][x] !== 'unknown'}
                    title={`${String.fromCharCode(65 + x)}${y + 1}`}
                  >
                    {getCellSymbol(x, y)}
                  </button>
                ))}
              </div>
            ))}
          </div>

          {/* Attack Controls */}
          <div className="mt-6 flex items-center justify-between">
            <div className="text-sm text-foreground/70">
              {selectedCell 
                ? `Ready to attack ${String.fromCharCode(65 + selectedCell.x)}${selectedCell.y + 1}`
                : 'Select a coordinate to attack'
              }
            </div>
            <button
              onClick={handleAttack}
              disabled={!selectedCell || !isMyTurn || isAttacking}
              className="flex items-center space-x-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
            >
              {isAttacking ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-2 border-primary-foreground border-t-transparent"></div>
                  <span>Attacking...</span>
                </>
              ) : (
                <>
                  <Target className="h-4 w-4" />
                  <span>Fire!</span>
                </>
              )}
            </button>
          </div>

          {(attackError || actionError) && (
            <div className="mt-4 p-3 bg-error/10 border border-error/20 rounded-lg">
              <p className="text-error text-sm">
                Error: {((attackError || actionError) as Error)?.message || 'Action failed'}
              </p>
            </div>
          )}
        </div>

        {/* Action Cards */}
        <div className="space-y-4">
          <h3 className="text-xl font-bold text-foreground">Action Cards</h3>
          
          {/* Placeholder for action cards - would come from fleet setup */}
          <div className="space-y-2">
            <div className="p-3 bg-card border border-border rounded-lg">
              <div className="flex items-center justify-between mb-2">
                <span className="font-semibold text-card-foreground">Torpedo Barrage</span>
                <Zap className="h-4 w-4 text-accent" />
              </div>
              <p className="text-sm text-card-foreground/70 mb-3">
                Attack 3x3 area for massive damage
              </p>
              <button
                disabled={!isMyTurn || isUsingAction}
                className="w-full px-3 py-2 bg-accent text-accent-foreground rounded hover:bg-accent/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-sm font-semibold"
              >
                Use Action
              </button>
            </div>

            <div className="p-3 bg-card border border-border rounded-lg opacity-50">
              <div className="flex items-center justify-between mb-2">
                <span className="font-semibold text-card-foreground">Sonar Ping</span>
                <Zap className="h-4 w-4 text-accent" />
              </div>
              <p className="text-sm text-card-foreground/70 mb-3">
                Reveal enemy ships in target area
              </p>
              <button
                disabled
                className="w-full px-3 py-2 bg-secondary text-secondary-foreground rounded cursor-not-allowed text-sm font-semibold"
              >
                Used
              </button>
            </div>
          </div>

          {/* Game Stats */}
          <div className="bg-card border border-border rounded-lg p-4">
            <h4 className="font-semibold text-card-foreground mb-3">Battle Stats</h4>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-card-foreground/70">Shots Fired:</span>
                <span className="text-card-foreground">0</span>
              </div>
              <div className="flex justify-between">
                <span className="text-card-foreground/70">Hits:</span>
                <span className="text-card-foreground">0</span>
              </div>
              <div className="flex justify-between">
                <span className="text-card-foreground/70">Accuracy:</span>
                <span className="text-card-foreground">0%</span>
              </div>
              <div className="flex justify-between">
                <span className="text-card-foreground/70">Actions Used:</span>
                <span className="text-card-foreground">1/10</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Turn Status */}
      {!isMyTurn && (
        <div className="bg-secondary/20 border border-secondary rounded-lg p-4 text-center">
          <div className="flex items-center justify-center space-x-2 mb-2">
            <div className="animate-pulse w-2 h-2 bg-secondary rounded-full"></div>
            <span className="text-secondary font-semibold">Waiting for opponent's move...</span>
          </div>
          <p className="text-secondary/80 text-sm">
            Your opponent is planning their attack. Stand by!
          </p>
        </div>
      )}
    </div>
  )
}