import { useAccount } from 'wagmi'
import { useContractRead, useContractWrite } from './useContract'

export function useLootbox() {
  const { address } = useAccount()
  
  // Read current lootbox price
  const { data: lootboxPrice, refetch: refetchPrice } = useContractRead(
    'LootboxSystem',
    'getLootboxPrice',
    [],
    { watch: true }
  )

  // Read user's purchased but unopened lootboxes
  const { data: unopenedCount, refetch: refetchUnopened } = useContractRead(
    'LootboxSystem',
    'getUnopenedLootboxCount',
    address ? [address] : undefined,
    { enabled: !!address, watch: true }
  )

  // Write functions
  const { 
    writeContract: purchaseLootbox, 
    isPending: isPurchasing,
    isConfirmed: isPurchaseConfirmed,
    error: purchaseError 
  } = useContractWrite('LootboxSystem')

  const { 
    writeContract: openLootbox, 
    isPending: isOpening,
    isConfirmed: isOpenConfirmed,
    error: openError 
  } = useContractWrite('LootboxSystem')

  const buyLootbox = async () => {
    if (!lootboxPrice) return
    return purchaseLootbox('purchaseLootbox', [], {
      value: lootboxPrice
    })
  }

  const openLootboxes = async (count: number = 1) => {
    return openLootbox('openLootboxes', [count])
  }

  const refetchAll = () => {
    refetchPrice()
    refetchUnopened()
  }

  return {
    // Data
    lootboxPrice,
    unopenedCount: unopenedCount ? Number(unopenedCount) : 0,
    
    // Actions
    buyLootbox,
    openLootboxes,
    refetchAll,
    
    // States
    isPurchasing,
    isOpening,
    isPurchaseConfirmed,
    isOpenConfirmed,
    
    // Errors
    purchaseError,
    openError,
  }
}