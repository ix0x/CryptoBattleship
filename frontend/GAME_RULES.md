# CryptoBattleship Game Rules

## ✅ Corrected Fleet Setup Rules

### 🚢 **Ship Selection** (Required)
- **1 Ship NFT required** per game
- Ship determines crew capacity and battle stats

### 👨‍✈️ **Captain Selection** (Required)  
- **1 Captain NFT required** per game
- Provides special abilities and battle bonuses

### 👥 **Crew Selection** (Optional)
- **Crew capacity determined by ship NFT:**
  - **Destroyer**: 2 + rarity bonus crew
  - **Submarine**: 3 + rarity bonus crew  
  - **Cruiser**: 4 + rarity bonus crew
  - **Battleship**: 6 + rarity bonus crew
  - **Carrier**: 8 + rarity bonus crew
- **Rarity bonus**: +0 to +4 additional crew slots
- **Dynamic capacity**: Each ship NFT has individual `shipCrewCapacity`

### ⚡ **Action Cards** (Optional)
- **No limit** on action card selection
- Bring as many as you own
- **Battle restriction**: Maximum 3 actions per turn (`MAX_ACTIONS_PER_TURN = 3`)
- Strategic selection based on battle plan

## 🎮 **Game Flow**

1. **Lobby**: Create/join games with ante
2. **Fleet Setup**: Select ship → crew (based on capacity) → captain → actions  
3. **Ship Placement**: Place 5 ships on 10x10 grid
4. **Battle**: Turn-based combat with action usage limits

## 🔧 **Frontend Implementation**

- ✅ Dynamic crew capacity from `ShipNFTManager.shipCrewCapacity(tokenId)`
- ✅ Unlimited action selection (UI updated)
- ✅ Ship selection clears crew when changed
- ✅ Real-time capacity display
- ✅ Contract-accurate validation

## 📝 **Key Changes Made**

1. **Removed arbitrary limits**:
   - ❌ "Up to 5 crew total" → ✅ Ship-specific capacity
   - ❌ "Up to 10 actions" → ✅ Unlimited selection

2. **Added dynamic capacity**:
   - Contract call to get ship's actual crew capacity
   - UI updates based on selected ship

3. **Improved UX**:
   - Clear capacity indicators
   - Loading states for contract calls
   - Helpful messages and explanations