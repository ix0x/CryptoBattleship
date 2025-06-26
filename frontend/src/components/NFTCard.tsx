'use client'

import { LucideIcon } from 'lucide-react'
import SVGRenderer from './SVGRenderer'

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
            <div className="flex justify-between text-xs">
              <span className="text-card-foreground/60">Size:</span>
              <span className="text-card-foreground">{nft.attributes.size}</span>
            </div>
          )}
          {nft.type === 'CAPTAIN' && (
            <div className="flex justify-between text-xs">
              <span className="text-card-foreground/60">Ability:</span>
              <span className="text-card-foreground">{nft.attributes.ability}</span>
            </div>
          )}
          {nft.type === 'ACTION' && (
            <div className="flex justify-between text-xs">
              <span className="text-card-foreground/60">Damage:</span>
              <span className="text-card-foreground">{nft.attributes.damage}</span>
            </div>
          )}
          {nft.type === 'CREW' && (
            <div className="flex justify-between text-xs">
              <span className="text-card-foreground/60">Type:</span>
              <span className="text-card-foreground">{nft.attributes.crewType}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}