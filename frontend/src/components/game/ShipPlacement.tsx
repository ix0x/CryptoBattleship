'use client'

import { useState, useEffect } from 'react'
import { RotateCw, Check, RefreshCw } from 'lucide-react'
import { useContractWrite } from '@/hooks/useContract'

interface ShipPlacementProps {
  gameId: number
}

type ShipType = 0 | 1 | 2 | 3 | 4 // destroyer, submarine, cruiser, battleship, carrier
type Rotation = 0 | 1 | 2 | 3 // NORTH, EAST, SOUTH, WEST

interface Ship {
  type: ShipType
  size: number
  name: string
  x: number
  y: number
  rotation: Rotation
  placed: boolean
}

const SHIP_TYPES: { type: ShipType; size: number; name: string; count: number }[] = [
  { type: 0, size: 2, name: 'Destroyer', count: 1 },
  { type: 1, size: 3, name: 'Submarine', count: 1 },
  { type: 2, size: 3, name: 'Cruiser', count: 1 },
  { type: 3, size: 4, name: 'Battleship', count: 1 },
  { type: 4, size: 5, name: 'Carrier', count: 1 },
]

const GRID_SIZE = 10

export default function ShipPlacement({ gameId }: ShipPlacementProps) {
  const [grid, setGrid] = useState<(number | null)[][]>(
    Array(GRID_SIZE).fill(null).map(() => Array(GRID_SIZE).fill(null))
  )
  const [ships, setShips] = useState<Ship[]>(
    SHIP_TYPES.map((shipType, index) => ({
      type: shipType.type,
      size: shipType.size,
      name: shipType.name,
      x: 0,
      y: 0,
      rotation: 0,
      placed: false,
    }))
  )
  const [selectedShip, setSelectedShip] = useState<number>(0)
  const [dragStart, setDragStart] = useState<{ x: number; y: number } | null>(null)

  // Get fleet data from localStorage (set in FleetSetup)
  const [fleetData, setFleetData] = useState<any>(null)

  useEffect(() => {
    const storedFleet = localStorage.getItem(`fleet_${gameId}`)
    if (storedFleet) {
      setFleetData(JSON.parse(storedFleet))
    }
  }, [gameId])

  const { writeContract: placeShips, isPending: isPlacing, error: placeError } = useContractWrite('BattleshipGame')

  const canPlaceShip = (ship: Ship, x: number, y: number, rotation: Rotation): boolean => {
    const positions = getShipPositions(ship.size, x, y, rotation)
    
    // Check if all positions are within bounds
    if (positions.some(pos => pos.x < 0 || pos.x >= GRID_SIZE || pos.y < 0 || pos.y >= GRID_SIZE)) {
      return false
    }

    // Check if any position is occupied by another ship
    return positions.every(pos => {
      const cell = grid[pos.y][pos.x]
      return cell === null || cell === selectedShip
    })
  }

  const getShipPositions = (size: number, x: number, y: number, rotation: Rotation) => {
    const positions = []
    for (let i = 0; i < size; i++) {
      switch (rotation) {
        case 0: // NORTH
          positions.push({ x, y: y - i })
          break
        case 1: // EAST
          positions.push({ x: x + i, y })
          break
        case 2: // SOUTH
          positions.push({ x, y: y + i })
          break
        case 3: // WEST
          positions.push({ x: x - i, y })
          break
      }
    }
    return positions
  }

  const placeShip = (shipIndex: number, x: number, y: number) => {
    const ship = ships[shipIndex]
    if (!canPlaceShip(ship, x, y, ship.rotation)) return

    // Clear previous position
    const newGrid = grid.map(row => [...row])
    if (ship.placed) {
      const oldPositions = getShipPositions(ship.size, ship.x, ship.y, ship.rotation)
      oldPositions.forEach(pos => {
        if (pos.x >= 0 && pos.x < GRID_SIZE && pos.y >= 0 && pos.y < GRID_SIZE) {
          newGrid[pos.y][pos.x] = null
        }
      })
    }

    // Place ship in new position
    const positions = getShipPositions(ship.size, x, y, ship.rotation)
    positions.forEach(pos => {
      newGrid[pos.y][pos.x] = shipIndex
    })

    setGrid(newGrid)
    setShips(prev => prev.map((s, i) => 
      i === shipIndex ? { ...s, x, y, placed: true } : s
    ))
  }

  const rotateShip = (shipIndex: number) => {
    const ship = ships[shipIndex]
    const newRotation = ((ship.rotation + 1) % 4) as Rotation
    
    if (ship.placed && !canPlaceShip(ship, ship.x, ship.y, newRotation)) {
      return // Can't rotate in current position
    }

    if (ship.placed) {
      // Clear current position
      const newGrid = grid.map(row => [...row])
      const oldPositions = getShipPositions(ship.size, ship.x, ship.y, ship.rotation)
      oldPositions.forEach(pos => {
        if (pos.x >= 0 && pos.x < GRID_SIZE && pos.y >= 0 && pos.y < GRID_SIZE) {
          newGrid[pos.y][pos.x] = null
        }
      })

      // Place in new rotation
      const newPositions = getShipPositions(ship.size, ship.x, ship.y, newRotation)
      newPositions.forEach(pos => {
        newGrid[pos.y][pos.x] = shipIndex
      })
      setGrid(newGrid)
    }

    setShips(prev => prev.map((s, i) => 
      i === shipIndex ? { ...s, rotation: newRotation } : s
    ))
  }

  const clearGrid = () => {
    setGrid(Array(GRID_SIZE).fill(null).map(() => Array(GRID_SIZE).fill(null)))
    setShips(prev => prev.map(s => ({ ...s, placed: false, x: 0, y: 0 })))
  }

  const allShipsPlaced = ships.every(ship => ship.placed)

  const handleConfirmPlacement = async () => {
    if (!allShipsPlaced || !fleetData) return

    try {
      // Extract NFT IDs from fleet data
      const shipId = parseInt(fleetData.ship.id.split('_')[1]) || 1 // Mock ID
      const captainId = parseInt(fleetData.captain.id.split('_')[1]) || 1 // Mock ID
      const actionIds = fleetData.actions.map((action: any) => parseInt(action.id.split('_')[1]) || 1)
      const crewIds = fleetData.crew.map((crew: any) => parseInt(crew.id.split('_')[1]) || 1)

      // Ensure arrays have valid values (0 for empty slots)
      // Action IDs - no padding needed, contract accepts any length
      // Crew IDs - no padding needed, contract accepts any length

      // Prepare ship placement data
      const shipTypes = ships.map(ship => ship.type)
      const xPositions = ships.map(ship => ship.x)
      const yPositions = ships.map(ship => ship.y)
      const rotations = ships.map(ship => ship.rotation)

      await placeShips('placeShips', [
        gameId,
        shipId,
        actionIds,
        captainId,
        crewIds,
        shipTypes,
        xPositions,
        yPositions,
        rotations
      ])
    } catch (error) {
      console.error('Failed to place ships:', error)
    }
  }

  const getCellColor = (x: number, y: number) => {
    const shipIndex = grid[y][x]
    if (shipIndex === null) return 'bg-blue-100 hover:bg-blue-200'
    
    const colors = [
      'bg-green-200', // Destroyer
      'bg-yellow-200', // Submarine
      'bg-orange-200', // Cruiser
      'bg-red-200', // Battleship
      'bg-purple-200', // Carrier
    ]
    return colors[shipIndex] || 'bg-gray-200'
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      {/* Instructions */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h2 className="text-2xl font-bold text-card-foreground mb-4">Place Your Ships</h2>
        <p className="text-card-foreground/70 mb-4">
          Click on the grid to place your selected ship. Use the rotate button to change orientation.
          Ships cannot overlap or touch each other.
        </p>
        <div className="flex items-center justify-between">
          <div className="text-sm text-card-foreground/80">
            Ships placed: {ships.filter(s => s.placed).length}/5
          </div>
          <button
            onClick={clearGrid}
            className="flex items-center space-x-2 px-4 py-2 text-accent hover:text-accent/80 transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            <span>Clear All</span>
          </button>
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-8">
        {/* Ship Selection */}
        <div className="space-y-4">
          <h3 className="text-xl font-bold text-foreground">Your Ships</h3>
          {ships.map((ship, index) => (
            <div
              key={index}
              className={`p-4 border rounded-lg cursor-pointer transition-all ${
                selectedShip === index
                  ? 'border-primary bg-primary/10'
                  : 'border-border hover:border-primary/50'
              } ${ship.placed ? 'bg-green-50' : ''}`}
              onClick={() => setSelectedShip(index)}
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-semibold text-foreground">{ship.name}</div>
                  <div className="text-sm text-foreground/70">Size: {ship.size} cells</div>
                </div>
                <div className="flex items-center space-x-2">
                  {ship.placed && <Check className="h-4 w-4 text-green-500" />}
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      rotateShip(index)
                    }}
                    className="p-1 hover:bg-secondary/50 rounded transition-colors"
                  >
                    <RotateCw className="h-4 w-4 text-accent" />
                  </button>
                </div>
              </div>
              <div className="mt-2 text-xs text-foreground/60">
                Rotation: {['North', 'East', 'South', 'West'][ship.rotation]}
              </div>
            </div>
          ))}
        </div>

        {/* Game Grid */}
        <div className="lg:col-span-2">
          <h3 className="text-xl font-bold text-foreground mb-4">Your Grid</h3>
          <div className="inline-block border-2 border-border rounded-lg overflow-hidden">
            <div className="grid grid-cols-10 gap-0">
              {Array.from({ length: GRID_SIZE }, (_, y) =>
                Array.from({ length: GRID_SIZE }, (_, x) => (
                  <button
                    key={`${x}-${y}`}
                    className={`w-8 h-8 border border-border ${getCellColor(x, y)} transition-colors`}
                    onClick={() => placeShip(selectedShip, x, y)}
                    title={`${x}, ${y}`}
                  />
                ))
              )}
            </div>
          </div>

          {/* Ship Legend */}
          <div className="mt-4 flex flex-wrap gap-2 text-xs">
            <div className="flex items-center space-x-1">
              <div className="w-3 h-3 bg-green-200 border border-gray-300"></div>
              <span>Destroyer</span>
            </div>
            <div className="flex items-center space-x-1">
              <div className="w-3 h-3 bg-yellow-200 border border-gray-300"></div>
              <span>Submarine</span>
            </div>
            <div className="flex items-center space-x-1">
              <div className="w-3 h-3 bg-orange-200 border border-gray-300"></div>
              <span>Cruiser</span>
            </div>
            <div className="flex items-center space-x-1">
              <div className="w-3 h-3 bg-red-200 border border-gray-300"></div>
              <span>Battleship</span>
            </div>
            <div className="flex items-center space-x-1">
              <div className="w-3 h-3 bg-purple-200 border border-gray-300"></div>
              <span>Carrier</span>
            </div>
          </div>
        </div>
      </div>

      {/* Confirm Placement */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-bold text-card-foreground">Ready for Battle?</h3>
            <p className="text-card-foreground/70">
              {allShipsPlaced 
                ? 'All ships placed! Confirm to start the battle.'
                : `Place all ${ships.length} ships to continue.`
              }
            </p>
          </div>
          <button
            onClick={handleConfirmPlacement}
            disabled={!allShipsPlaced || isPlacing}
            className="px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
          >
            {isPlacing ? 'Placing Ships...' : 'Confirm Placement'}
          </button>
        </div>

        {placeError && (
          <div className="mt-4 p-3 bg-error/10 border border-error/20 rounded-lg">
            <p className="text-error text-sm">
              Error: {(placeError as Error)?.message || 'Failed to place ships'}
            </p>
          </div>
        )}
      </div>
    </div>
  )
}