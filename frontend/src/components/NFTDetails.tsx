'use client'

import { X, ExternalLink, Copy, Check } from 'lucide-react'
import { LucideIcon } from 'lucide-react'
import { useState } from 'react'
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

interface NFTDetailsProps {
  nft: NFT
  onClose: () => void
  rarityColors: Record<string, string>
  typeIcons: Record<string, LucideIcon>
}

export default function NFTDetails({ nft, onClose, rarityColors, typeIcons }: NFTDetailsProps) {
  const [copied, setCopied] = useState(false)
  const Icon = typeIcons[nft.type]

  const copyTokenId = async () => {
    await navigator.clipboard.writeText(nft.id)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const renderAttributes = () => {
    switch (nft.type) {
      case 'SHIP':
        return (
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Ship Type:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.shipType}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Size:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.size} cells</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Speed:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.speed}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Damage:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.damage}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Health:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.health}</span>
            </div>
          </div>
        )
      
      case 'CAPTAIN':
        return (
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Ability:</span>
              <span className="font-semibold text-card-foreground">{String(nft.attributes.ability).replace('_', ' ')}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Boost:</span>
              <span className="font-semibold text-card-foreground">+{nft.attributes.boost}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Experience:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.experience}</span>
            </div>
          </div>
        )
      
      case 'CREW':
        return (
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Crew Type:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.crewType}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Boost:</span>
              <span className="font-semibold text-card-foreground">+{nft.attributes.boost}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Specialty:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.specialty}</span>
            </div>
          </div>
        )
      
      case 'ACTION':
        return (
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Category:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.category}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Damage:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.damage}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-card-foreground/70">Range:</span>
              <span className="font-semibold text-card-foreground">{nft.attributes.range} cells</span>
            </div>
          </div>
        )
      
      default:
        return null
    }
  }

  return (
    <div className="bg-card border border-border rounded-lg p-6 sticky top-8">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-accent/10 rounded-lg">
            <Icon className="h-6 w-6 text-accent" />
          </div>
          <div>
            <h3 className="text-xl font-bold text-card-foreground">{nft.name}</h3>
            <p className="text-card-foreground/70">{nft.type} • {nft.rarity}</p>
          </div>
        </div>
        <button 
          onClick={onClose}
          className="p-2 hover:bg-secondary/50 rounded-lg transition-colors"
        >
          <X className="h-5 w-5 text-card-foreground/70" />
        </button>
      </div>

      {/* SVG Art */}
      <div className="mb-6">
        <div className={`aspect-square rounded-lg overflow-hidden border-2 ${rarityColors[nft.rarity]}`}>
          <SVGRenderer nft={nft} className="w-full h-full" />
        </div>
      </div>

      {/* Rarity Badge */}
      <div className="mb-6">
        <div className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold ${rarityColors[nft.rarity]} border`}>
          <div className="w-2 h-2 rounded-full bg-current mr-2"></div>
          {nft.rarity}
        </div>
      </div>

      {/* Attributes */}
      <div className="mb-6">
        <h4 className="font-semibold text-card-foreground mb-3">Attributes</h4>
        <div className="bg-secondary/10 rounded-lg p-4">
          {renderAttributes()}
        </div>
      </div>

      {/* Token Info */}
      <div className="mb-6">
        <h4 className="font-semibold text-card-foreground mb-3">Token Info</h4>
        <div className="space-y-2 text-sm">
          <div className="flex items-center justify-between">
            <span className="text-card-foreground/70">Token ID:</span>
            <div className="flex items-center space-x-2">
              <span className="font-mono text-card-foreground">#{nft.id}</span>
              <button 
                onClick={copyTokenId}
                className="p-1 hover:bg-secondary/50 rounded transition-colors"
              >
                {copied ? (
                  <Check className="h-4 w-4 text-success" />
                ) : (
                  <Copy className="h-4 w-4 text-card-foreground/70" />
                )}
              </button>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-card-foreground/70">Contract:</span>
            <span className="font-mono text-card-foreground/70 text-xs">0x1234...5678</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-card-foreground/70">Standard:</span>
            <span className="text-card-foreground">ERC-721</span>
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="space-y-3">
        <button className="w-full px-4 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold">
          Use in Battle
        </button>
        
        <button className="w-full px-4 py-3 bg-secondary text-secondary-foreground border border-border rounded-lg hover:bg-secondary/80 transition-colors font-semibold flex items-center justify-center space-x-2">
          <ExternalLink className="h-4 w-4" />
          <span>View on Explorer</span>
        </button>
        
        {nft.type === 'SHIP' && (
          <button className="w-full px-4 py-3 bg-accent/20 text-accent border border-accent/30 rounded-lg hover:bg-accent/30 transition-colors font-semibold">
            Retire for Credits
          </button>
        )}
      </div>

      {/* Art Generation Info */}
      <div className="mt-6 p-3 bg-accent/10 border border-accent/20 rounded-lg">
        <p className="text-xs text-card-foreground/80">
          <strong>On-Chain Art:</strong> This NFT&apos;s artwork is generated and stored entirely on-chain using SVG. 
          The art is procedurally created based on the token&apos;s attributes and rarity.
        </p>
      </div>
    </div>
  )
}