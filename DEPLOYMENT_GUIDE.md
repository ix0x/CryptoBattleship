# 🚀 CryptoBattleship Sonic Blaze Deployment Guide

## Prerequisites

1. **Node.js & npm** installed
2. **Wallet with Sonic Blaze testnet funds**
   - Get testnet S tokens from [Sonic Faucet](https://faucet.soniclabs.com)
   - Network: Sonic Blaze Testnet
   - Chain ID: 57054
   - RPC: https://rpc.blaze.soniclabs.com
   - Explorer: https://testnet.sonicscan.org

## 🛠️ Quick Deployment

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment
```bash
cp .env.example .env
```

Edit `.env` with your details:
```env
PRIVATE_KEY=your_private_key_without_0x
INITIAL_ADMIN=your_admin_wallet_address
TEAM_TREASURY=your_treasury_wallet_address
```

### 3. Deploy to Sonic Blaze
```bash
# Compile contracts
npm run compile

# Deploy all contracts
npm run deploy:sonic

# Verify contracts (optional)
npm run verify:sonic

# Set up initial configuration
npm run setup:sonic
```

## 📋 What Gets Deployed

### Core Contracts
- **BattleshipToken** - ERC20 token (SHIP)
- **GameConfig** - Game parameters and settings
- **BattleshipGame** - Main game logic with 1S ante

### NFT Contracts (Split Architecture)
- **ShipNFTManager** - Ship NFTs with placard + grid SVGs
- **ActionNFTManager** - Action NFTs with placard + animation SVGs  
- **CaptainAndCrewNFTManager** - Captain/Crew NFTs with placard SVGs

### Supporting Systems
- **TokenomicsCore** - Credits, emissions, revenue distribution
- **StakingPool** - Token staking rewards
- **LootboxSystem** - NFT lootboxes (10 SHIP each)
- **Testnet Faucet** - Built into BattleshipToken (100 SHIP per day)

## ⚙️ Initial Configuration

The setup script automatically configures:

### Game Parameters
- **Turn Timer**: 5 minutes per turn
- **Ante Amount**: 1 S (standardized for testing)
- **Game Fee**: 5% to protocol
- **Weekly Emissions**: 10,000 SHIP tokens

### Action Templates
- **Cross Blast**: 2x2 area damage (Common)
- **Line Shot**: 3-cell penetrating attack (Uncommon)
- **Energy Shield**: Defensive barrier (Common)

### NFT System
- **Military Fleet** variant active for ships
- **Template system** ready for actions
- **Placeholder art** with rarity-based colors

## 🎮 Testing Your Deployment

### 1. Create a Game
```javascript
// Connect to BattleshipGame contract
const gameId = await battleshipGame.createGame(1); // FISH size
// Ante: 1 S required
```

### 2. Get SHIP Tokens (Testnet Faucet)
```javascript
// Connect to BattleshipToken contract
await battleshipToken.claimFromFaucet(); // Claims 100 SHIP tokens
// Users can claim once every 24 hours
```

### 3. Buy Lootboxes
```javascript
// Connect to LootboxSystem contract
const lootboxId = await lootboxSystem.buyLootbox(battleshipTokenAddress, parseEther("10"));
const nfts = await lootboxSystem.openLootbox(lootboxId);
```

### 4. Join Game with NFTs
```javascript
// Use NFTs from lootbox in game
await battleshipGame.joinGame(gameId, shipIds, captainId, crewIds);
```

## 📁 Generated Files

After deployment, you'll have:
- `deployment-sonic-blaze.json` - Contract addresses
- `setup-complete-sonic-blaze.json` - Configuration summary

## 🔧 Admin Functions

As the deployer, you can:

### Manage Faucet
```javascript
// Disable faucet for production
await battleshipToken.toggleFaucet(false);

// Check faucet status for a user
const [nextClaim, canClaim, timeUntil] = await battleshipToken.getFaucetInfo(userAddress);
```

### Manage Seasons
```javascript
// Create new ship variant
await shipNFTManager.createNewVariant("Pirate Fleet", 2, 2, true, statMods);

// Switch active variant  
await shipNFTManager.setActiveVariant(2);
```

### Add Action Templates
```javascript
await actionNFTManager.addActionTemplate(
  "Mega Blast",        // name
  "Massive explosion", // description
  [0,1,10,11,20,21],  // 3x2 pattern
  3,                   // damage
  4,                   // range
  1,                   // uses
  0,                   // OFFENSIVE
  3,                   // EPIC rarity
  false,               // not seasonal
  0                    // season 0
);
```

### Update Configuration
```javascript
// Change turn timer
await gameConfig.updateTurnTimer(600); // 10 minutes

// Update emission rate
await gameConfig.updateWeeklyEmissionRate(parseEther("15000"));

// Modify ante system
await battleshipGame.updateAnteConfig(true, parseEther("2")); // 2S ante
```

## 🌐 Frontend Integration

Update your frontend with the deployed contract addresses from `deployment-sonic-blaze.json`:

```typescript
// Update your config/contracts.ts
export const CONTRACTS = {
  BattleshipGame: "0x...",
  ShipNFTManager: "0x...",
  ActionNFTManager: "0x...",
  CaptainAndCrewNFTManager: "0x...",
  LootboxSystem: "0x...",
  // ... other contracts
};

export const NETWORK = {
  chainId: 57054,
  name: "Sonic Blaze Testnet",
  rpc: "https://rpc.blaze.soniclabs.com",
  explorer: "https://testnet.sonicscan.org"
};
```

## ❗ Important Notes

### Security
- **Admin keys**: Secure your private key - it controls all contracts
- **Multi-sig**: Consider using a multi-sig wallet for production
- **Upgrades**: Contracts are not upgradeable - deploy new versions if needed

### Testing
- Claim SHIP tokens from faucet for testing lootboxes
- Start with small amounts for testing
- Verify all functions work before announcing
- Test both successful and failure scenarios

### Monitoring
- Watch contract events for activity
- Monitor gas usage and optimization opportunities
- Track revenue and tokenomics flows

## 🆘 Troubleshooting

### Common Issues

**Deployment Fails**
- Check account balance (need S for gas)
- Verify network configuration
- Ensure all dependencies installed

**Verification Fails**
- Wait a few minutes after deployment
- Check constructor arguments match
- Sonic verification may take time

**Setup Script Fails**
- Ensure deployment completed first
- Check admin permissions
- Verify contract addresses

### Support
- Check logs in deployment scripts
- Verify on Sonic Explorer
- Test individual contract functions

## 🎉 Success!

Your CryptoBattleship deployment is ready when you see:
- ✅ All contracts deployed and verified
- ✅ Initial configuration complete
- ✅ Action templates created
- ✅ NFT minting permissions set
- ✅ 1S ante system active

**Ready to battle! ⚓🎮**