'use client'

import { useState } from 'react'
import { Shield, Settings, Zap, Users, Coins, AlertTriangle, Play, RefreshCw } from 'lucide-react'
import { useAccount } from 'wagmi'
import { useContractRead, useContractWrite } from '@/hooks/useContract'
import { parseEther, formatEther } from 'viem'

export default function AdminDashboard() {
  const { address } = useAccount()
  const [selectedContract, setSelectedContract] = useState<string>('BattleshipGame')
  const [emergencyMode, setEmergencyMode] = useState(false)
  const [newAnteAmount, setNewAnteAmount] = useState('')
  const [selectedGameSize, setSelectedGameSize] = useState(0)

  // Check if user is admin (this would need proper access control in production)
  const isAdmin = address && address.toLowerCase() === '0x...' // Replace with actual admin check

  // Get contract states
  const { data: gameContractPaused } = useContractRead('BattleshipGame', 'paused', [])
  const { data: stakingContractPaused } = useContractRead('StakingPool', 'paused', [])
  const { data: currentAntes } = useContractRead('BattleshipGame', 'anteAmounts', [selectedGameSize])
  const { data: totalGames } = useContractRead('GameState', 'nextGameId', [])
  const { data: totalStaked } = useContractRead('StakingPool', 'getTotalStaked', [])

  // Admin contract interactions
  const { writeContract: pauseGame, isPending: isPausingGame } = useContractWrite('BattleshipGame')
  const { writeContract: pauseStaking, isPending: isPausingStaking } = useContractWrite('StakingPool')
  const { writeContract: setAnteAmount, isPending: isSettingAnte } = useContractWrite('BattleshipGame')
  const { writeContract: forceEndGame, isPending: isForcingEnd } = useContractWrite('BattleshipGame')
  const { writeContract: emergencyWithdraw, isPending: isWithdrawing } = useContractWrite('StakingPool')

  const contracts = [
    { name: 'BattleshipGame', address: '0x1aB0C9a6B5635F1B3109a6Fa5dC22A37ded2a9fA' },
    { name: 'StakingPool', address: '0x...' },
    { name: 'BattleshipToken', address: '0x49Dcf31d2e807F2DdC25357EBaE1C40EC29aF6Cd' },
    { name: 'LootboxSystem', address: '0x3Bb7Ae609779A8393A0A96d0F4516E813D857C4E' },
  ]

  const gameSizes = ['Shrimp', 'Fish', 'Shark', 'Whale']

  const handlePauseContract = async (contractName: string) => {
    try {
      if (contractName === 'BattleshipGame') {
        await pauseGame('pause', [])
      } else if (contractName === 'StakingPool') {
        await pauseStaking('pause', [])
      }
    } catch (error) {
      console.error('Failed to pause contract:', error)
    }
  }

  const handleUnpauseContract = async (contractName: string) => {
    try {
      if (contractName === 'BattleshipGame') {
        await pauseGame('unpause', [])
      } else if (contractName === 'StakingPool') {
        await pauseStaking('unpause', [])
      }
    } catch (error) {
      console.error('Failed to unpause contract:', error)
    }
  }

  const handleSetAnteAmount = async () => {
    if (!newAnteAmount) return
    
    try {
      await setAnteAmount('setAnteAmount', [selectedGameSize, parseEther(newAnteAmount)])
      setNewAnteAmount('')
    } catch (error) {
      console.error('Failed to set ante amount:', error)
    }
  }

  const handleForceEndGame = async (gameId: number) => {
    try {
      await forceEndGame('forceEndGame', [gameId, address]) // Winner address
    } catch (error) {
      console.error('Failed to force end game:', error)
    }
  }

  if (!isAdmin) {
    return (
      <div className="max-w-4xl mx-auto p-8">
        <div className="bg-card border border-border rounded-lg p-8 text-center">
          <Shield className="h-12 w-12 text-red-500 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-card-foreground mb-2">Access Denied</h2>
          <p className="text-card-foreground/70">
            You don't have administrator privileges to access this dashboard.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      {/* Header */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-4">
          <div className="p-3 bg-red-100 rounded-lg">
            <Shield className="h-8 w-8 text-red-600" />
          </div>
          <div>
            <h1 className="text-3xl font-bold text-card-foreground">Admin Dashboard</h1>
            <p className="text-card-foreground/70">Contract management and emergency controls</p>
          </div>
        </div>
        
        <div className="grid md:grid-cols-4 gap-4 mt-6">
          <div className="text-center">
            <div className="text-2xl font-bold text-primary mb-1">
              {totalGames ? Number(totalGames) : 0}
            </div>
            <div className="text-sm text-card-foreground/70">Total Games</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-accent mb-1">
              {totalStaked ? formatEther(totalStaked as bigint) : '0'}
            </div>
            <div className="text-sm text-card-foreground/70">Total Staked</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-green-500 mb-1">
              {gameContractPaused ? 'Paused' : 'Active'}
            </div>
            <div className="text-sm text-card-foreground/70">Game Contract</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-green-500 mb-1">
              {stakingContractPaused ? 'Paused' : 'Active'}
            </div>
            <div className="text-sm text-card-foreground/70">Staking Contract</div>
          </div>
        </div>
      </div>

      {/* Emergency Controls */}
      <div className="bg-red-50 border border-red-200 rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-4">
          <AlertTriangle className="h-6 w-6 text-red-600" />
          <h2 className="text-xl font-bold text-red-800">Emergency Controls</h2>
        </div>
        
        <div className="grid md:grid-cols-2 gap-4">
          <div className="space-y-3">
            <h3 className="font-semibold text-red-700">Contract Pause/Unpause</h3>
            <div className="space-y-2">
              <div className="flex items-center justify-between p-3 bg-white rounded border">
                <span className="font-medium">BattleshipGame</span>
                <div className="flex space-x-2">
                  <button
                    onClick={() => handlePauseContract('BattleshipGame')}
                    disabled={isPausingGame || gameContractPaused}
                    className="px-3 py-1 bg-red-500 text-white rounded hover:bg-red-600 disabled:opacity-50 text-sm"
                  >
                    Pause
                  </button>
                  <button
                    onClick={() => handleUnpauseContract('BattleshipGame')}
                    disabled={isPausingGame || !gameContractPaused}
                    className="px-3 py-1 bg-green-500 text-white rounded hover:bg-green-600 disabled:opacity-50 text-sm"
                  >
                    Unpause
                  </button>
                </div>
              </div>
              
              <div className="flex items-center justify-between p-3 bg-white rounded border">
                <span className="font-medium">StakingPool</span>
                <div className="flex space-x-2">
                  <button
                    onClick={() => handlePauseContract('StakingPool')}
                    disabled={isPausingStaking || stakingContractPaused}
                    className="px-3 py-1 bg-red-500 text-white rounded hover:bg-red-600 disabled:opacity-50 text-sm"
                  >
                    Pause
                  </button>
                  <button
                    onClick={() => handleUnpauseContract('StakingPool')}
                    disabled={isPausingStaking || !stakingContractPaused}
                    className="px-3 py-1 bg-green-500 text-white rounded hover:bg-green-600 disabled:opacity-50 text-sm"
                  >
                    Unpause
                  </button>
                </div>
              </div>
            </div>
          </div>
          
          <div className="space-y-3">
            <h3 className="font-semibold text-red-700">Emergency Actions</h3>
            <div className="space-y-2">
              <button
                onClick={() => handleForceEndGame(1)} // Example game ID
                disabled={isForcingEnd}
                className="w-full px-4 py-2 bg-orange-500 text-white rounded hover:bg-orange-600 disabled:opacity-50"
              >
                {isForcingEnd ? 'Processing...' : 'Force End Game #1'}
              </button>
              
              <button
                onClick={() => emergencyWithdraw('emergencyWithdraw', [])}
                disabled={isWithdrawing}
                className="w-full px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50"
              >
                {isWithdrawing ? 'Processing...' : 'Emergency Withdraw'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Game Configuration */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-4">
          <Settings className="h-6 w-6 text-accent" />
          <h2 className="text-xl font-bold text-card-foreground">Game Configuration</h2>
        </div>
        
        <div className="space-y-4">
          <div>
            <h3 className="font-semibold text-card-foreground mb-3">Ante Amounts</h3>
            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-card-foreground mb-2">
                  Game Size
                </label>
                <select
                  value={selectedGameSize}
                  onChange={(e) => setSelectedGameSize(Number(e.target.value))}
                  className="w-full px-3 py-2 border border-border rounded-lg bg-background text-foreground"
                >
                  {gameSizes.map((size, index) => (
                    <option key={index} value={index}>{size}</option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-card-foreground mb-2">
                  New Ante Amount (ETH)
                </label>
                <div className="flex space-x-2">
                  <input
                    type="number"
                    step="0.001"
                    value={newAnteAmount}
                    onChange={(e) => setNewAnteAmount(e.target.value)}
                    placeholder={currentAntes ? formatEther(currentAntes as bigint) : '0.001'}
                    className="flex-1 px-3 py-2 border border-border rounded-lg bg-background text-foreground"
                  />
                  <button
                    onClick={handleSetAnteAmount}
                    disabled={!newAnteAmount || isSettingAnte}
                    className="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50"
                  >
                    {isSettingAnte ? 'Setting...' : 'Set'}
                  </button>
                </div>
              </div>
            </div>
            
            <div className="mt-3 text-sm text-card-foreground/70">
              Current {gameSizes[selectedGameSize]} ante: {currentAntes ? formatEther(currentAntes as bigint) : '0'} ETH
            </div>
          </div>
        </div>
      </div>

      {/* Contract Information */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center space-x-3 mb-4">
          <Zap className="h-6 w-6 text-accent" />
          <h2 className="text-xl font-bold text-card-foreground">Contract Information</h2>
        </div>
        
        <div className="grid md:grid-cols-2 gap-4">
          {contracts.map((contract, index) => (
            <div key={index} className="p-4 bg-secondary/10 rounded-lg border border-secondary/20">
              <div className="flex items-center justify-between mb-2">
                <h3 className="font-semibold text-card-foreground">{contract.name}</h3>
                <span className="text-xs px-2 py-1 bg-accent/20 text-accent rounded">
                  Deployed
                </span>
              </div>
              <p className="text-sm text-card-foreground/70 font-mono break-all">
                {contract.address}
              </p>
              <div className="mt-2 flex space-x-2">
                <button className="text-xs px-2 py-1 bg-primary text-primary-foreground rounded hover:bg-primary/90">
                  View on Explorer
                </button>
                <button className="text-xs px-2 py-1 bg-secondary text-secondary-foreground rounded hover:bg-secondary/80">
                  Verify Contract
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}