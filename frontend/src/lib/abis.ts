// Contract ABIs for CryptoBattleship
// Note: These will be populated with actual ABIs from artifacts

import BattleshipTokenArtifact from '../../artifacts/contracts/BattleshipToken.sol/BattleshipToken.json'
import ShipNFTManagerArtifact from '../../artifacts/contracts/ShipNFTManager.sol/ShipNFTManager.json'
import ActionNFTManagerArtifact from '../../artifacts/contracts/ActionNFTManager.sol/ActionNFTManager.json'
import CaptainNFTManagerArtifact from '../../artifacts/contracts/CaptainNFTManager.sol/CaptainNFTManager.json'
import CrewNFTManagerArtifact from '../../artifacts/contracts/CrewNFTManager.sol/CrewNFTManager.json'
import StakingPoolArtifact from '../../artifacts/contracts/StakingPool.sol/StakingPool.json'
import BattleshipGameArtifact from '../../artifacts/contracts/BattleshipGame.sol/BattleshipGame.json'
import LootboxSystemArtifact from '../../artifacts/contracts/LootboxSystem.sol/LootboxSystem.json'
import GameConfigArtifact from '../../artifacts/contracts/GameConfig.sol/GameConfig.json'
import TokenomicsCoreArtifact from '../../artifacts/contracts/TokenomicsCore.sol/TokenomicsCore.json'

export const ABIS = {
  BattleshipToken: BattleshipTokenArtifact.abi,
  ShipNFTManager: ShipNFTManagerArtifact.abi,
  ActionNFTManager: ActionNFTManagerArtifact.abi,
  CaptainNFTManager: CaptainNFTManagerArtifact.abi,
  CrewNFTManager: CrewNFTManagerArtifact.abi,
  StakingPool: StakingPoolArtifact.abi,
  BattleshipGame: BattleshipGameArtifact.abi,
  LootboxSystem: LootboxSystemArtifact.abi,
  GameConfig: GameConfigArtifact.abi,
  TokenomicsCore: TokenomicsCoreArtifact.abi,
} as const

export type AbiName = keyof typeof ABIS