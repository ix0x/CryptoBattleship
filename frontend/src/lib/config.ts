import { Chain } from 'wagmi/chains'

// Sonic Blaze Testnet Configuration
export const sonicBlaze: Chain = {
  id: 57054,
  name: 'Sonic Blaze Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'Sonic',
    symbol: 'S',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.soniclabs.com'],
      webSocket: ['wss://rpc.soniclabs.com'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Sonic Explorer',
      url: 'https://explorer.soniclabs.com',
    },
  },
  testnet: true,
}

// Contract addresses from deployment
export const CONTRACT_ADDRESSES = {
  BattleshipToken: '0x49Dcf31d2e807F2DdC25357EBaE1C40EC29aF6Cd',
  GameConfig: '0x1cF2808BE19AFbbC28fD9B7DEA6DB822BE472971',
  ShipNFTManager: '0x90932BC326bCc7eb61007E373648bE6352E71a90',
  ActionNFTManager: '0xF339ff707Ee7Ced2b4F1823A3C4a069D23AFA56A',
  CaptainNFTManager: '0xFa5b0033df93a2c5c0CDc7374d88Bd4a824032f2',
  CrewNFTManager: '0x17e9BDFD27FFd16Bf7543180534dF28f8F64d998',
  StakingPool: '0x927631B321C09635f9E814CAe9D53ED9A831A5E4',
  TokenomicsCore: '0x8476CA865B651F20dAfbb3eddE301BC5B933aCFF',
  GameState: '0x7D9e8Eda47cCe0F3dD274cCa6c349dB0C0cc8743',
  GameLogic: '0x24a04C8aD00E2b5eBb04E8390c3feD6FCC5d83aF',
  BattleshipGame: '0x1aB0C9a6B5635F1B3109a6Fa5dC22A37ded2a9fA',
  LootboxSystem: '0x3Bb7Ae609779A8393A0A96d0F4516E813D857C4E',
} as const

export type ContractName = keyof typeof CONTRACT_ADDRESSES