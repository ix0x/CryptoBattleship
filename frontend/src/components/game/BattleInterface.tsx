'use client'

import { useState, useEffect } from 'react'
import { Target, Zap, Clock, User, SkipForward } from 'lucide-react'
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
  const [turnTimeLeft, setTurnTimeLeft] = useState<number>(0)
  const [canForceSkip, setCanForceSkip] = useState<boolean>(false)
  const [availableActions, setAvailableActions] = useState<any[]>([])
  const [usedActions, setUsedActions] = useState<number[]>([])
  const [selectedAction, setSelectedAction] = useState<number | null>(null)

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
  const { writeContract: forceSkipTurn, isPending: isSkipping, error: skipError } = useContractWrite('BattleshipGame')

  useEffect(() => {
    if (contractGameInfo) {
      setGameInfo(contractGameInfo)
    }
  }, [contractGameInfo])

  // Load available actions from localStorage (set during fleet setup)
  useEffect(() => {
    const storedFleet = localStorage.getItem(`fleet_${gameId}`)
    if (storedFleet) {
      try {
        const fleetData = JSON.parse(storedFleet)
        setAvailableActions(fleetData.actions || [])
      } catch (error) {
        console.error('Failed to load fleet actions:', error)
      }
    }
  }, [gameId])

  // Turn timer logic
  useEffect(() => {
    if (!gameInfo || !address) return

    const TURN_TIMEOUT = 300 // 5 minutes in seconds
    const now = Math.floor(Date.now() / 1000)
    const turnStartTime = Number(gameInfo.lastMoveTime || 0)
    const timeElapsed = now - turnStartTime
    const timeLeft = Math.max(0, TURN_TIMEOUT - timeElapsed)

    setTurnTimeLeft(timeLeft)
    setCanForceSkip(timeLeft === 0 && !isMyTurn)

    // Update timer every second
    const interval = setInterval(() => {
      const currentTime = Math.floor(Date.now() / 1000)
      const elapsed = currentTime - turnStartTime
      const remaining = Math.max(0, TURN_TIMEOUT - elapsed)
      
      setTurnTimeLeft(remaining)
      setCanForceSkip(remaining === 0 && !isMyTurn)
      
      if (remaining === 0) {
        clearInterval(interval)
      }
    }, 1000)

    return () => clearInterval(interval)
  }, [gameInfo, address, isMyTurn])

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

  const handleForceSkip = async () => {
    if (!canForceSkip || isSkipping) return

    try {
      await forceSkipTurn('forceSkipTurn', [gameId])
      refetchGameInfo()
    } catch (error) {
      console.error('Force skip failed:', error)
    }
  }

  const formatTime = (seconds: number): string => {
    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = seconds % 60
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`
  }

  const handleUseAction = async (actionIndex: number) => {
    if (!selectedCell || !isMyTurn || isUsingAction || usedActions.includes(actionIndex)) return
    
    const action = availableActions[actionIndex]
    if (!action) return

    try {
      // Extract action ID from action NFT
      const actionId = parseInt(action.id.split('_')[1]) || 1
      
      await useAction('useActionCard', [
        gameId,
        actionId,
        selectedCell.x,
        selectedCell.y,
        0 // Additional parameters if needed
      ])
      
      // Mark action as used
      setUsedActions(prev => [...prev, actionIndex])
      setSelectedAction(null)
      setSelectedCell(null)
      refetchGameInfo()
    } catch (error) {
      console.error('Action usage failed:', error)
    }
  }

  const canUseAction = (actionIndex: number): boolean => {
    return isMyTurn && 
           !isUsingAction && 
           !usedActions.includes(actionIndex) && 
           selectedCell !== null &&
           usedActions.length < 3 // MAX_ACTIONS_PER_TURN = 3
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
              Time left: <span className={`font-mono ${turnTimeLeft < 60 ? 'text-red-500' : 'text-accent'}`}>
                {formatTime(turnTimeLeft)}
              </span>
            </div>
            {canForceSkip && (
              <button
                onClick={handleForceSkip}
                disabled={isSkipping}
                className="mt-2 px-3 py-1 text-xs bg-red-500 text-white rounded-lg hover:bg-red-600 disabled:opacity-50 transition-colors"
              >
                {isSkipping ? 'Skipping...' : 'Force Skip Turn'}
              </button>
            )}
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
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-bold text-foreground">Action Cards</h3>
            <div className="text-sm text-foreground/70">
              Used: {usedActions.length}/3 this turn
            </div>
          </div>
          
          {availableActions.length > 0 ? (
            <div className="space-y-2">
              {availableActions.map((action, index) => {
                const isUsed = usedActions.includes(index)
                const canUse = canUseAction(index)
                const isSelected = selectedAction === index
                
                return (
                  <div 
                    key={index}
                    className={`p-3 border rounded-lg transition-all ${
                      isUsed 
                        ? 'bg-gray-100 border-gray-200 opacity-50' 
                        : isSelected
                          ? 'bg-accent/10 border-accent'
                          : 'bg-card border-border hover:border-accent/50'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-semibold text-card-foreground">{action.name}</span>
                      <div className="flex items-center space-x-2">
                        <Zap className="h-4 w-4 text-accent" />
                        <span className="text-xs px-2 py-1 bg-secondary/20 rounded">
                          {action.rarity}
                        </span>
                      </div>
                    </div>
                    
                    <p className="text-sm text-card-foreground/70 mb-3">
                      {action.attributes.description || `Damage: ${action.attributes.damage || 50}`}
                    </p>
                    
                    <div className="flex items-center space-x-2">
                      <button
                        onClick={() => setSelectedAction(isSelected ? null : index)}
                        disabled={isUsed || !isMyTurn}
                        className={`flex-1 px-3 py-2 rounded text-sm font-semibold transition-colors ${
                          isSelected
                            ? 'bg-accent text-accent-foreground'
                            : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'
                        } disabled:opacity-50 disabled:cursor-not-allowed`}
                      >
                        {isSelected ? 'Selected' : 'Select'}
                      </button>
                      
                      <button
                        onClick={() => handleUseAction(index)}
                        disabled={!canUse || selectedAction !== index}
                        className="px-4 py-2 bg-primary text-primary-foreground rounded hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-sm font-semibold"
                      >
                        {isUsed ? 'Used' : isUsingAction ? 'Using...' : 'Use'}
                      </button>
                    </div>
                    
                    {selectedAction === index && !selectedCell && (
                      <div className="mt-2 text-xs text-orange-600 bg-orange-50 rounded px-2 py-1">
                        Select a target coordinate first
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          ) : (
            <div className="text-center py-6 bg-secondary/10 rounded-lg">
              <Zap className="h-8 w-8 text-secondary/50 mx-auto mb-2" />
              <p className="text-secondary/70">No action cards equipped</p>
              <p className="text-xs text-secondary/50">Select actions during fleet setup</p>
            </div>
          )}
          
          {usedActions.length >= 3 && (
            <div className="text-center py-2 bg-yellow-50 border border-yellow-200 rounded">
              <p className="text-yellow-700 text-sm">Maximum actions used this turn</p>
            </div>
          )}
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

      {/* Error Messages */}
      {skipError && (
        <div className="bg-error/10 border border-error/20 rounded-lg p-4">
          <p className="text-error text-sm">
            Error forcing skip: {(skipError as Error)?.message || 'Failed to skip turn'}
          </p>
        </div>
      )}
    </div>
  )
}