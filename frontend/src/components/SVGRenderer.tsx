'use client'

import { useState, useEffect, useCallback } from 'react'
import PlaceholderImage from './PlaceholderImage'
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

interface SVGRendererProps {
  nft: NFT
  className?: string
}

interface Colors {
  primary: string
  secondary: string
  accent: string
}

// Helper functions moved outside component
const getRarityColors = (rarity: string): Colors => {
  switch (rarity) {
    case 'COMMON': return { primary: '#6b7280', secondary: '#9ca3af', accent: '#d1d5db' }
    case 'UNCOMMON': return { primary: '#059669', secondary: '#10b981', accent: '#6ee7b7' }
    case 'RARE': return { primary: '#2563eb', secondary: '#3b82f6', accent: '#93c5fd' }
    case 'EPIC': return { primary: '#7c3aed', secondary: '#8b5cf6', accent: '#c4b5fd' }
    case 'LEGENDARY': return { primary: '#ea580c', secondary: '#f97316', accent: '#fdba74' }
    default: return { primary: '#6b7280', secondary: '#9ca3af', accent: '#d1d5db' }
  }
}

const generateShipSVG = (nft: NFT, colors: Colors, size: number): string => {
  const shipType = nft.attributes.shipType || 'DESTROYER'
  const health = nft.attributes.health || 60
  const damage = nft.attributes.damage || 45
  
  return `
    <svg width="${size}" height="${size}" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="shipGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:${colors.primary};stop-opacity:1" />
          <stop offset="100%" style="stop-color:${colors.secondary};stop-opacity:1" />
        </linearGradient>
        <filter id="glow">
          <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
          <feMerge> 
            <feMergeNode in="coloredBlur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
      </defs>
      
      <!-- Ocean Background -->
      <rect width="200" height="200" fill="#0f1b2e"/>
      <circle cx="100" cy="100" r="80" fill="url(#shipGrad)" opacity="0.1"/>
      
      <!-- Ship Hull -->
      <ellipse cx="100" cy="120" rx="60" ry="20" fill="url(#shipGrad)" filter="url(#glow)"/>
      <ellipse cx="100" cy="115" rx="50" ry="15" fill="${colors.accent}"/>
      
      <!-- Masts based on ship type -->
      ${shipType === 'CARRIER' ? `
        <rect x="95" y="60" width="10" height="60" fill="${colors.primary}"/>
        <rect x="75" y="70" width="8" height="50" fill="${colors.primary}"/>
        <rect x="117" y="70" width="8" height="50" fill="${colors.primary}"/>
      ` : `
        <rect x="95" y="70" width="10" height="50" fill="${colors.primary}"/>
        <rect x="110" y="75" width="8" height="45" fill="${colors.primary}"/>
      `}
      
      <!-- Sails -->
      <polygon points="90,75 90,95 120,95 120,75" fill="${colors.accent}" opacity="0.8"/>
      
      <!-- Health/Damage indicators -->
      <circle cx="30" cy="30" r="15" fill="${colors.primary}" opacity="0.8"/>
      <text x="30" y="35" text-anchor="middle" fill="white" font-size="12" font-weight="bold">${health}</text>
      
      <circle cx="170" cy="30" r="15" fill="${colors.secondary}" opacity="0.8"/>
      <text x="170" y="35" text-anchor="middle" fill="white" font-size="12" font-weight="bold">${damage}</text>
      
      <!-- Ship Name -->
      <text x="100" y="180" text-anchor="middle" fill="${colors.accent}" font-size="14" font-weight="bold">${nft.name}</text>
    </svg>
  `
}

const generateCaptainSVG = (nft: NFT, colors: Colors, size: number): string => {
  const boost = nft.attributes.boost || 10
  
  return `
    <svg width="${size}" height="${size}" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <radialGradient id="captainGrad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" style="stop-color:${colors.accent};stop-opacity:0.8" />
          <stop offset="100%" style="stop-color:${colors.primary};stop-opacity:0.3" />
        </radialGradient>
      </defs>
      
      <!-- Background -->
      <rect width="200" height="200" fill="#0f1b2e"/>
      <circle cx="100" cy="100" r="90" fill="url(#captainGrad)"/>
      
      <!-- Captain Portrait -->
      <circle cx="100" cy="80" r="40" fill="${colors.primary}" stroke="${colors.accent}" stroke-width="3"/>
      <circle cx="100" cy="75" r="35" fill="${colors.secondary}"/>
      
      <!-- Hat -->
      <ellipse cx="100" cy="50" rx="35" ry="10" fill="${colors.primary}"/>
      <rect x="85" y="40" width="30" height="15" fill="${colors.primary}"/>
      
      <!-- Eyes -->
      <circle cx="90" cy="75" r="3" fill="white"/>
      <circle cx="110" cy="75" r="3" fill="white"/>
      
      <!-- Ability Icon -->
      <circle cx="100" cy="150" r="25" fill="${colors.accent}" opacity="0.8"/>
      <text x="100" y="157" text-anchor="middle" fill="white" font-size="16" font-weight="bold">+${boost}%</text>
      
      <!-- Captain Name -->
      <text x="100" y="185" text-anchor="middle" fill="${colors.accent}" font-size="12" font-weight="bold">${nft.name}</text>
    </svg>
  `
}

const generateCrewSVG = (nft: NFT, colors: Colors, size: number): string => {
  const crewType = nft.attributes.crewType || 'GUNNER'
  const boost = nft.attributes.boost || 5
  
  return `
    <svg width="${size}" height="${size}" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
      <!-- Background -->
      <rect width="200" height="200" fill="#0f1b2e"/>
      
      <!-- Crew Figure -->
      <circle cx="100" cy="70" r="25" fill="${colors.primary}"/>
      <rect x="85" y="90" width="30" height="40" fill="${colors.secondary}"/>
      
      <!-- Tool/Weapon based on crew type -->
      ${crewType === 'GUNNER' ? `
        <rect x="70" y="100" width="20" height="5" fill="${colors.accent}"/>
        <circle cx="65" cy="102" r="3" fill="${colors.accent}"/>
      ` : crewType === 'ENGINEER' ? `
        <rect x="75" y="95" width="3" height="15" fill="${colors.accent}"/>
        <rect x="72" y="105" width="9" height="3" fill="${colors.accent}"/>
      ` : `
        <rect x="75" y="95" width="2" height="20" fill="${colors.accent}"/>
      `}
      
      <!-- Boost Indicator -->
      <circle cx="100" cy="150" r="20" fill="${colors.primary}" opacity="0.8"/>
      <text x="100" y="157" text-anchor="middle" fill="white" font-size="14" font-weight="bold">+${boost}</text>
      
      <!-- Crew Name -->
      <text x="100" y="185" text-anchor="middle" fill="${colors.accent}" font-size="12" font-weight="bold">${nft.name}</text>
    </svg>
  `
}

const generateActionSVG = (nft: NFT, colors: Colors, size: number): string => {
  const category = nft.attributes.category || 'OFFENSIVE'
  const damage = nft.attributes.damage || 50
  
  return `
    <svg width="${size}" height="${size}" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
      <!-- Background -->
      <rect width="200" height="200" fill="#0f1b2e"/>
      
      <!-- Action Symbol -->
      ${category === 'OFFENSIVE' ? `
        <polygon points="100,50 120,90 100,80 80,90" fill="${colors.primary}"/>
        <circle cx="100" cy="100" r="15" fill="${colors.secondary}"/>
        <polygon points="90,120 110,120 105,140 95,140" fill="${colors.accent}"/>
      ` : `
        <circle cx="100" cy="100" r="30" fill="${colors.primary}" opacity="0.8"/>
        <circle cx="100" cy="100" r="20" fill="${colors.secondary}"/>
        <rect x="95" y="90" width="10" height="20" fill="${colors.accent}"/>
      `}
      
      <!-- Damage/Effect Value -->
      <circle cx="100" cy="150" r="25" fill="${colors.accent}" opacity="0.8"/>
      <text x="100" y="157" text-anchor="middle" fill="white" font-size="16" font-weight="bold">${damage}</text>
      
      <!-- Action Name -->
      <text x="100" y="185" text-anchor="middle" fill="${colors.accent}" font-size="12" font-weight="bold">${nft.name}</text>
    </svg>
  `
}

const generateDefaultSVG = (nft: NFT, colors: Colors, size: number): string => {
  return `
    <svg width="${size}" height="${size}" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
      <rect width="200" height="200" fill="#0f1b2e"/>
      <circle cx="100" cy="100" r="50" fill="${colors.primary}"/>
      <text x="100" y="107" text-anchor="middle" fill="white" font-size="16" font-weight="bold">${nft.type}</text>
      <text x="100" y="180" text-anchor="middle" fill="${colors.accent}" font-size="12" font-weight="bold">${nft.name}</text>
    </svg>
  `
}

export default function SVGRenderer({ nft, className = "" }: SVGRendererProps) {
  const [svgContent, setSvgContent] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Extract token ID from NFT ID (format: "type_tokenId")
  const tokenId = parseInt(nft.id.split('_')[1]) || 1

  // Get contract name based on NFT type
  const getContractName = (type: string) => {
    switch (type) {
      case 'SHIP': return 'ShipNFTManager'
      case 'CAPTAIN': return 'CaptainNFTManager'  
      case 'CREW': return 'CrewNFTManager'
      case 'ACTION': return 'ActionNFTManager'
      default: return null
    }
  }

  const contractName = getContractName(nft.type)

  // Try to get real SVG from contract
  const { data: contractSVG, isLoading: isContractLoading, error: contractError } = useContractRead(
    contractName as any,
    nft.type === 'SHIP' ? 'generatePlacardSVG' : 'tokenURI',
    [tokenId],
    { enabled: !!contractName && tokenId > 0 }
  )

  const generateMockSVG = useCallback((nft: NFT): string => {
    const colors = getRarityColors(nft.rarity)
    const size = 200

    switch (nft.type) {
      case 'SHIP':
        return generateShipSVG(nft, colors, size)
      case 'CAPTAIN':
        return generateCaptainSVG(nft, colors, size)
      case 'CREW':
        return generateCrewSVG(nft, colors, size)
      case 'ACTION':
        return generateActionSVG(nft, colors, size)
      default:
        return generateDefaultSVG(nft, colors, size)
    }
  }, [])

  useEffect(() => {
    const processSVG = async () => {
      setIsLoading(true)
      setError(null)
      
      try {
        // First try to use real contract SVG
        if (contractSVG && !contractError) {
          if (nft.type === 'SHIP') {
            // For ships, generatePlacardSVG returns raw SVG
            setSvgContent(contractSVG as string)
          } else {
            // For other NFTs, tokenURI returns base64 encoded JSON with image field
            try {
              const decoded = atob((contractSVG as string).replace('data:application/json;base64,', ''))
              const metadata = JSON.parse(decoded)
              if (metadata.image && metadata.image.startsWith('data:image/svg+xml;base64,')) {
                const svgDecoded = atob(metadata.image.replace('data:image/svg+xml;base64,', ''))
                setSvgContent(svgDecoded)
              } else {
                // Fallback to mock SVG
                setSvgContent(generateMockSVG(nft))
              }
            } catch {
              // If decoding fails, use mock SVG
              setSvgContent(generateMockSVG(nft))
            }
          }
        } else {
          // Fallback to mock SVG if contract call fails or is loading
          setSvgContent(generateMockSVG(nft))
        }
      } catch (err) {
        setError('Failed to load NFT art')
        console.error('SVG processing error:', err)
        setSvgContent(generateMockSVG(nft))
      } finally {
        setIsLoading(false)
      }
    }

    // Don't set loading if we're using contract data
    if (!isContractLoading) {
      processSVG()
    } else {
      setIsLoading(true)
    }
  }, [nft, contractSVG, contractError, isContractLoading, generateMockSVG])

  if (isLoading) {
    return (
      <div className={`${className} flex items-center justify-center bg-secondary/20 rounded`}>
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-accent border-t-transparent"></div>
      </div>
    )
  }

  if (error || !svgContent) {
    return (
      <PlaceholderImage 
        width={200} 
        height={200} 
        text={`${nft.name} NFT Art`}
        className={className}
      />
    )
  }

  return (
    <div 
      className={className}
      dangerouslySetInnerHTML={{ __html: svgContent }}
    />
  )
}