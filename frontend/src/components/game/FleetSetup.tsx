'use client'

import { useState, useEffect } from 'react'
import { Anchor, Shield, Users, Zap, Check } from 'lucide-react'
import { useUserNFTs, type NFT } from '@/hooks/useNFTs'
import { useContractRead, useContractWrite } from '@/hooks/useContract'
import NFTCard from '@/components/NFTCard'

interface FleetSetupProps {
  gameId: number
}

interface SelectedFleet {
  ship: NFT | null
  captain: NFT | null
  crew: NFT[]
  actions: NFT[]
}

interface ShipCapacity {
  crewCapacity: number
}

export default function FleetSetup({ gameId }: FleetSetupProps) {
  const { nfts, isLoading } = useUserNFTs()
  const [selectedFleet, setSelectedFleet] = useState<SelectedFleet>({
    ship: null,
    captain: null,
    crew: [],
    actions: []
  })
  const [shipCapacity, setShipCapacity] = useState<ShipCapacity>({ crewCapacity: 0 })

  // Get ship crew capacity from contract when ship is selected
  const selectedShipTokenId = selectedFleet.ship ? parseInt(selectedFleet.ship.id.split('_')[1]) || 1 : null
  const { data: contractShipCapacity } = useContractRead(
    'ShipNFTManager',
    'shipCrewCapacity',
    selectedShipTokenId ? [selectedShipTokenId] : undefined,
    { enabled: !!selectedShipTokenId }
  )

  // Update ship capacity when contract data changes
  useEffect(() => {
    if (contractShipCapacity) {
      setShipCapacity({ crewCapacity: Number(contractShipCapacity) })
    } else {
      setShipCapacity({ crewCapacity: 0 })
    }
  }, [contractShipCapacity])

  // Filter NFTs by type
  const ships = nfts.filter(nft => nft.type === 'SHIP')
  const captains = nfts.filter(nft => nft.type === 'CAPTAIN')
  const crewMembers = nfts.filter(nft => nft.type === 'CREW')
  const actions = nfts.filter(nft => nft.type === 'ACTION')

  const rarityColors = {
    COMMON: 'border-gray-400 bg-gray-400/10',
    UNCOMMON: 'border-green-400 bg-green-400/10',
    RARE: 'border-blue-400 bg-blue-400/10',
    EPIC: 'border-purple-400 bg-purple-400/10',
    LEGENDARY: 'border-orange-400 bg-orange-400/10'
  }

  const typeIcons = {
    SHIP: Anchor,
    ACTION: Zap,
    CAPTAIN: Shield,
    CREW: Users
  }

  const selectShip = (ship: NFT) => {
    setSelectedFleet(prev => ({ 
      ...prev, 
      ship,
      // Clear crew when ship changes since capacity might be different
      crew: []
    }))
  }

  const selectCaptain = (captain: NFT) => {
    setSelectedFleet(prev => ({ ...prev, captain }))
  }

  const toggleCrew = (crew: NFT) => {
    setSelectedFleet(prev => {
      const isSelected = prev.crew.some(c => c.id === crew.id)
      if (isSelected) {
        return { ...prev, crew: prev.crew.filter(c => c.id !== crew.id) }
      } else if (prev.crew.length < shipCapacity.crewCapacity) {
        return { ...prev, crew: [...prev.crew, crew] }
      }
      return prev
    })
  }

  const toggleAction = (action: NFT) => {
    setSelectedFleet(prev => {
      const isSelected = prev.actions.some(a => a.id === action.id)
      if (isSelected) {
        return { ...prev, actions: prev.actions.filter(a => a.id !== action.id) }
      } else {
        // No limit on action cards - only limited by ownership
        return { ...prev, actions: [...prev.actions, action] }
      }
    })
  }

  const isFleetComplete = selectedFleet.ship && selectedFleet.captain

  const { writeContract: confirmFleet, isPending: isConfirming, error: confirmError } = useContractWrite('BattleshipGame')

  const handleConfirmFleet = async () => {
    if (!isFleetComplete) return

    try {
      // For now, we'll just store the fleet locally and move to ship placement
      // The actual NFT validation happens during placeShips call
      console.log('Fleet confirmed:', selectedFleet)
      
      // In a real implementation, you might want to store this data locally
      // or call a contract function to register the fleet
      localStorage.setItem(`fleet_${gameId}`, JSON.stringify(selectedFleet))
      
      // The game state hook will detect this and move to ship placement
      window.location.reload()
    } catch (error) {
      console.error('Failed to confirm fleet:', error)
    }
  }

  if (isLoading) {
    return (
      <div className="text-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-2 border-primary border-t-transparent mx-auto mb-4"></div>
        <h3 className="text-xl font-semibold text-foreground mb-2">Loading Your NFTs...</h3>
        <p className="text-foreground/70">Fetching your fleet from the blockchain</p>
      </div>
    )
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      {/* Fleet Summary */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h2 className="text-2xl font-bold text-card-foreground mb-4">Your Fleet</h2>
        <div className="grid md:grid-cols-4 gap-4">
          <div className="text-center">
            <div className="text-sm text-card-foreground/60 mb-1">Ship</div>
            <div className="font-semibold text-card-foreground">
              {selectedFleet.ship ? selectedFleet.ship.name : 'Not selected'}
            </div>
          </div>
          <div className="text-center">
            <div className="text-sm text-card-foreground/60 mb-1">Captain</div>
            <div className="font-semibold text-card-foreground">
              {selectedFleet.captain ? selectedFleet.captain.name : 'Not selected'}
            </div>
          </div>
          <div className="text-center">
            <div className="text-sm text-card-foreground/60 mb-1">Crew</div>
            <div className="font-semibold text-card-foreground">
              {selectedFleet.crew.length}/{shipCapacity.crewCapacity || 0} selected
            </div>
            {shipCapacity.crewCapacity === 0 && selectedFleet.ship && (
              <div className="text-xs text-card-foreground/50">Loading capacity...</div>
            )}
          </div>
          <div className="text-center">
            <div className="text-sm text-card-foreground/60 mb-1">Actions</div>
            <div className="font-semibold text-card-foreground">
              {selectedFleet.actions.length} selected
            </div>
            <div className="text-xs text-card-foreground/50">No limit</div>
          </div>
        </div>
      </div>

      {/* Ship Selection */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-bold text-card-foreground mb-4 flex items-center">
          <Anchor className="h-5 w-5 mr-2" />
          Select Your Ship (Required)
        </h3>
        {ships.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-card-foreground/70">No ships available. Open some lootboxes to get ships!</p>
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {ships.map((ship) => (
              <div key={ship.id} className="relative">
                <NFTCard
                  nft={ship}
                  onClick={() => selectShip(ship)}
                  isSelected={selectedFleet.ship?.id === ship.id}
                  rarityColors={rarityColors}
                  typeIcons={typeIcons}
                />
                {selectedFleet.ship?.id === ship.id && (
                  <div className="absolute top-2 left-2 bg-primary text-primary-foreground rounded-full p-1">
                    <Check className="h-3 w-3" />
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Captain Selection */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-bold text-card-foreground mb-4 flex items-center">
          <Shield className="h-5 w-5 mr-2" />
          Select Your Captain (Required)
        </h3>
        {captains.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-card-foreground/70">No captains available. Open some lootboxes to get captains!</p>
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {captains.map((captain) => (
              <div key={captain.id} className="relative">
                <NFTCard
                  nft={captain}
                  onClick={() => selectCaptain(captain)}
                  isSelected={selectedFleet.captain?.id === captain.id}
                  rarityColors={rarityColors}
                  typeIcons={typeIcons}
                />
                {selectedFleet.captain?.id === captain.id && (
                  <div className="absolute top-2 left-2 bg-primary text-primary-foreground rounded-full p-1">
                    <Check className="h-3 w-3" />
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Crew Selection */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-bold text-card-foreground mb-4 flex items-center">
          <Users className="h-5 w-5 mr-2" />
          Select Your Crew (Optional, up to {shipCapacity.crewCapacity || 0} based on ship)
        </h3>
        {selectedFleet.ship && (
          <div className="mb-4 p-3 bg-secondary/10 rounded-lg">
            <p className="text-sm text-card-foreground/80">
              <strong>{selectedFleet.ship.name}</strong> can hold <strong>{shipCapacity.crewCapacity || 0}</strong> crew members.
              Crew capacity is determined by your ship's type and rarity.
            </p>
          </div>
        )}
        {!selectedFleet.ship ? (
          <div className="text-center py-8">
            <div className="text-4xl mb-3">⚓</div>
            <p className="text-card-foreground/70">Select a ship first to see crew capacity</p>
          </div>
        ) : crewMembers.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-card-foreground/70">No crew members available. Open some lootboxes to get crew!</p>
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {crewMembers.map((crew) => (
              <div key={crew.id} className="relative">
                <NFTCard
                  nft={crew}
                  onClick={() => toggleCrew(crew)}
                  isSelected={selectedFleet.crew.some(c => c.id === crew.id)}
                  rarityColors={rarityColors}
                  typeIcons={typeIcons}
                />
                {selectedFleet.crew.some(c => c.id === crew.id) && (
                  <div className="absolute top-2 left-2 bg-primary text-primary-foreground rounded-full p-1">
                    <Check className="h-3 w-3" />
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Action Selection */}
      <div className="bg-card border border-border rounded-lg p-6">
        <h3 className="text-xl font-bold text-card-foreground mb-4 flex items-center">
          <Zap className="h-5 w-5 mr-2" />
          Select Your Actions (Optional, unlimited selection)
        </h3>
        <div className="mb-4 p-3 bg-accent/10 rounded-lg border border-accent/20">
          <p className="text-sm text-card-foreground/80">
            <strong>Action Usage:</strong> You can bring any number of action cards, but can only use up to 3 actions per turn during battle.
            Choose strategically based on your battle plan!
          </p>
        </div>
        {actions.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-card-foreground/70">No action cards available. Open some lootboxes to get actions!</p>
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {actions.map((action) => (
              <div key={action.id} className="relative">
                <NFTCard
                  nft={action}
                  onClick={() => toggleAction(action)}
                  isSelected={selectedFleet.actions.some(a => a.id === action.id)}
                  rarityColors={rarityColors}
                  typeIcons={typeIcons}
                />
                {selectedFleet.actions.some(a => a.id === action.id) && (
                  <div className="absolute top-2 left-2 bg-primary text-primary-foreground rounded-full p-1">
                    <Check className="h-3 w-3" />
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Confirm Fleet */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-bold text-card-foreground">Ready to Deploy?</h3>
            <p className="text-card-foreground/70">
              {isFleetComplete 
                ? 'Your fleet is ready! Confirm to proceed to ship placement.'
                : 'Please select at least one ship and one captain to continue.'
              }
            </p>
          </div>
          <button
            onClick={handleConfirmFleet}
            disabled={!isFleetComplete || isConfirming}
            className="px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
          >
            {isConfirming ? 'Confirming...' : 'Confirm Fleet'}
          </button>
        </div>

        {confirmError && (
          <div className="mt-4 p-3 bg-error/10 border border-error/20 rounded-lg">
            <p className="text-error text-sm">
              Error: {(confirmError as Error)?.message || 'Failed to confirm fleet'}
            </p>
          </div>
        )}
      </div>
    </div>
  )
}