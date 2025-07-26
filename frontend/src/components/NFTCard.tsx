'use client'

import { LucideIcon } from 'lucide-react'
import { Heart, AlertTriangle } from 'lucide-react'
import SVGRenderer from './SVGRenderer'
import { useContractRead } from '@/hooks/useContract'

interface NFT {
  id: string
  type: 'SHIP' | 'ACTION' | 'CAPTAIN' | 'CREW'
  rarity: 'COMMON' | 'UNCOMMON' | 'RARE' | 'EPIC' | 'LEGENDARY'
  name: string
  tokenURI?: string
  svgData?: string
  attributes: Record<string, string | number>
}

interface NFTCardProps {
  nft: NFT
  onClick: () => void
  isSelected: boolean
  rarityColors: Record<string, string>
  typeIcons: Record<string, LucideIcon>
}

export default function NFTCard({ nft, onClick, isSelected, rarityColors, typeIcons }: NFTCardProps) {
  const Icon = typeIcons[nft.type]
  
  // Extract token ID for contract calls
  const tokenId = parseInt(nft.id.split('_')[1]) || 1

  // Get ship condition/usability data for ships
  const { data: canUseShip } = useContractRead(
    'ShipNFTManager',
    'canUseShip',
    [tokenId],
    { enabled: nft.type === 'SHIP' }
  )

  const { data: shipStats } = useContractRead(
    'ShipNFTManager',
    'ships',
    [tokenId],
    { enabled: nft.type === 'SHIP' }
  )

  // Get captain abilities
  const { data: captainStats } = useContractRead(
    'CaptainNFTManager',
    'captains',
    [tokenId],
    { enabled: nft.type === 'CAPTAIN' }
  )

  // Get crew abilities
  const { data: crewStats } = useContractRead(
    'CrewNFTManager',
    'crew',
    [tokenId],
    { enabled: nft.type === 'CREW' }
  )

  const shipCondition = shipStats ? {
    health: Number((shipStats as any).health || 100),
    maxHealth: Number((shipStats as any).maxHealth || 100),
    isDamaged: Number((shipStats as any).health || 100) < Number((shipStats as any).maxHealth || 100),
    isUsable: canUseShip !== false
  } : null
  
  return (
    <div 
      onClick={onClick}
      className={`bg-card border-2 rounded-lg p-4 cursor-pointer transition-all hover:scale-105 ${
        rarityColors[nft.rarity]
      } ${
        isSelected ? 'ring-2 ring-primary' : ''
      }`}
    >
      {/* NFT Image/SVG */}
      <div className="aspect-square mb-4 relative overflow-hidden rounded-lg bg-secondary/20">
        <SVGRenderer
          nft={nft}
          className="w-full h-full object-cover"
        />
        
        {/* Rarity Badge */}
        <div className="absolute top-2 right-2">
          <div className={`px-2 py-1 rounded text-xs font-bold ${rarityColors[nft.rarity]} border`}>
            {nft.rarity}
          </div>
        </div>
        
        {/* Type Icon */}
        <div className="absolute bottom-2 left-2">
          <div className="p-2 bg-card/80 backdrop-blur rounded-lg">
            <Icon className="h-4 w-4 text-accent" />
          </div>
        </div>
      </div>

      {/* NFT Info */}
      <div>
        <h3 className="font-semibold text-card-foreground mb-1 truncate">{nft.name}</h3>
        <p className="text-sm text-card-foreground/70 mb-2">#{nft.id}</p>
        
        {/* Quick Stats */}
        <div className="space-y-1">
          {nft.type === 'SHIP' && (
            <>
              <div className="flex justify-between text-xs">
                <span className="text-card-foreground/60">Size:</span>
                <span className="text-card-foreground">{nft.attributes.size}</span>
              </div>
              
              {/* Ship Condition Display */}
              {shipCondition && (
                <>
                  <div className="flex justify-between text-xs items-center">
                    <span className="text-card-foreground/60 flex items-center">
                      <Heart className="h-3 w-3 mr-1" />
                      Health:
                    </span>
                    <div className="flex items-center space-x-1">
                      <div className="w-12 h-1 bg-gray-200 rounded-full overflow-hidden">
                        <div 
                          className={`h-full transition-all ${
                            shipCondition.health > 80 ? 'bg-green-500' :
                            shipCondition.health > 50 ? 'bg-yellow-500' :
                            shipCondition.health > 20 ? 'bg-orange-500' : 'bg-red-500'
                          }`}
                          style={{ 
                            width: `${Math.max(0, (shipCondition.health / shipCondition.maxHealth) * 100)}%` 
                          }}
                        />
                      </div>
                      <span className="text-card-foreground text-xs">
                        {shipCondition.health}/{shipCondition.maxHealth}
                      </span>
                    </div>
                  </div>
                  
                  {shipCondition.isDamaged && (
                    <div className="flex items-center justify-center text-xs text-orange-600 bg-orange-50 rounded px-2 py-1">
                      <AlertTriangle className="h-3 w-3 mr-1" />
                      <span>Damaged</span>
                    </div>
                  )}
                  
                  {!shipCondition.isUsable && (
                    <div className="flex items-center justify-center text-xs text-red-600 bg-red-50 rounded px-2 py-1">
                      <AlertTriangle className="h-3 w-3 mr-1" />
                      <span>Cannot Use</span>
                    </div>
                  )}
                </>
              )}
            </>
          )}
          {nft.type === 'CAPTAIN' && (
            <>
              <div className="flex justify-between text-xs">
                <span className="text-card-foreground/60">Ability:</span>
                <span className="text-card-foreground">{nft.attributes.ability}</span>
              </div>
              
              {captainStats && (
                <>
                  <div className="flex justify-between text-xs">
                    <span className="text-card-foreground/60">Boost:</span>
                    <span className="text-accent font-semibold">
                      +{Number((captainStats as any).boost || 10)}%
                    </span>
                  </div>
                  
                  <div className="flex justify-between text-xs">
                    <span className="text-card-foreground/60">Specialty:</span>
                    <span className="text-card-foreground">
                      {(captainStats as any).specialty || 'Combat'}
                    </span>
                  </div>
                  
                  {(captainStats as any).cooldown && Number((captainStats as any).cooldown) > 0 && (
                    <div className="flex items-center justify-center text-xs text-orange-600 bg-orange-50 rounded px-2 py-1 mt-1">
                      <AlertTriangle className="h-3 w-3 mr-1" />
                      <span>Cooldown: {Number((captainStats as any).cooldown)}s</span>
                    </div>
                  )}
                </>
              )}
            </>
          )}
          {nft.type === 'ACTION' && (
            <div className="flex justify-between text-xs">
              <span className="text-card-foreground/60">Damage:</span>
              <span className="text-card-foreground">{nft.attributes.damage}</span>
            </div>
          )}
          {nft.type === 'CREW' && (
            <>
              <div className="flex justify-between text-xs">
                <span className="text-card-foreground/60">Type:</span>
                <span className="text-card-foreground">{nft.attributes.crewType}</span>
              </div>
              
              {crewStats && (
                <>
                  <div className="flex justify-between text-xs">
                    <span className="text-card-foreground/60">Skill:</span>
                    <span className="text-accent font-semibold">
                      +{Number((crewStats as any).skillBonus || 5)}
                    </span>
                  </div>
                  
                  <div className="flex justify-between text-xs">
                    <span className="text-card-foreground/60">Experience:</span>
                    <span className="text-card-foreground">
                      {Number((crewStats as any).experience || 0)} XP
                    </span>
                  </div>
                  
                  {(crewStats as any).isExhausted && (
                    <div className="flex items-center justify-center text-xs text-red-600 bg-red-50 rounded px-2 py-1 mt-1">
                      <AlertTriangle className="h-3 w-3 mr-1" />
                      <span>Exhausted</span>
                    </div>
                  )}
                </>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}