import { useState, useEffect } from 'react'
import { useAccount } from 'wagmi'
import { useContractRead } from './useContract'

export type GamePhase = 'lobby' | 'fleet-setup' | 'ship-placement' | 'battle' | 'ended'

export interface GameInfo {
  player1: string
  player2: string
  gameSize: number
  ante: bigint
  startTime: bigint
  status: number // 0=WAITING, 1=ACTIVE, 2=COMPLETED, 3=CANCELLED
  winner: string
  endTime: bigint
  currentPlayer: number
  lastMoveTime: bigint
  player1SkippedTurns: number
  player2SkippedTurns: number
  gameEnded: boolean
}

export function useGameState() {
  const { address } = useAccount()
  const [currentGameId, setCurrentGameId] = useState<number | null>(null)
  
  // Get player's active game
  const { data: activeGameId } = useContractRead(
    'BattleshipGame',
    'playerActiveGames',
    address ? [address] : undefined,
    { enabled: !!address, watch: true }
  )

  // Get game info if we have an active game
  const { data: gameInfo } = useContractRead(
    'BattleshipGame',
    'getGameInfo',
    currentGameId ? [currentGameId] : undefined,
    { enabled: !!currentGameId, watch: true }
  )

  // Get player fleet info
  const { data: playerFleet } = useContractRead(
    'GameState',
    'playerFleets',
    currentGameId && address ? [currentGameId, address] : undefined,
    { enabled: !!currentGameId && !!address, watch: true }
  )

  useEffect(() => {
    if (activeGameId && Number(activeGameId) > 0) {
      setCurrentGameId(Number(activeGameId))
    } else {
      setCurrentGameId(null)
    }
  }, [activeGameId])

  // Determine current game phase
  const getGamePhase = (): GamePhase => {
    if (!currentGameId || !gameInfo) {
      return 'lobby'
    }

    const info = gameInfo as unknown as GameInfo
    
    // Game not started yet
    if (info.status === 0) { // WAITING
      return 'lobby'
    }
    
    // Game ended
    if (info.status === 2 || info.status === 3) { // COMPLETED or CANCELLED
      return 'ended'
    }

    // Game is active, check player setup
    if (info.status === 1) { // ACTIVE
      if (!playerFleet || !(playerFleet as any).shipsPlaced) {
        // Check if we have a fleet setup
        if (!playerFleet || !(playerFleet as any).shipId || (playerFleet as any).shipId === 0) {
          return 'fleet-setup'
        }
        return 'ship-placement'
      }
      return 'battle'
    }

    return 'lobby'
  }

  return {
    currentGameId,
    gameInfo: gameInfo as unknown as GameInfo | undefined,
    playerFleet,
    gamePhase: getGamePhase(),
    setCurrentGameId,
  }
}