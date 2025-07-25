import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { sonicBlaze } from './config'

export const config = getDefaultConfig({
  appName: 'CryptoBattleship',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'placeholder',
  chains: [sonicBlaze],
  ssr: true,
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}