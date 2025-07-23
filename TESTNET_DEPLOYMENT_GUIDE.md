# CryptoBattleship V2 Testnet Deployment Guide

This document provides a comprehensive guide for deploying the CryptoBattleship V2 system to Sonic EVM testnet, including smart contracts and frontend integration.

---

## 📋 **Overview**

**Current Status**: 
- ✅ V2 Smart Contracts (TokenomicsCore, StakingPool) - Ready
- ✅ Frontend (Next.js + TypeScript + TailwindCSS) - Built
- ⏳ Testnet Deployment - Pending

**Target Network**: Sonic EVM Testnet

---

## 🔧 **Phase 1: Backend Setup (Smart Contracts)**

### **1.1 Hardhat Project Initialization**

```bash
# Navigate to project root
cd /home/ixi/CryptoBattleship/

# Initialize npm project
npm init -y

# Install Hardhat and toolbox
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox

# Initialize Hardhat project
npx hardhat init  # Choose "Create a TypeScript project"
```

### **1.2 Install Required Dependencies**

```bash
# OpenZeppelin contracts (already used in smart contracts)
npm install @openzeppelin/contracts @openzeppelin/contracts-upgradeable

# Development dependencies
npm install --save-dev @nomiclabs/hardhat-etherscan hardhat-gas-reporter
npm install --save-dev @typechain/ethers-v6 @typechain/hardhat

# Additional utilities
npm install dotenv
```

### **1.3 Hardhat Configuration**

Create/update `hardhat.config.ts`:

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-gas-reporter";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    sonic_testnet: {
      url: process.env.SONIC_RPC_URL || "https://rpc.testnet.soniclabs.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 64165, // Update with actual Sonic testnet chain ID
      gasPrice: "auto",
      gas: "auto",
    },
  },
  etherscan: {
    apiKey: {
      sonic_testnet: process.env.SONIC_EXPLORER_API_KEY || "your-api-key",
    },
    customChains: [
      {
        network: "sonic_testnet",
        chainId: 64165,
        urls: {
          apiURL: "https://api.testnet.soniclabs.com/api", // Update with actual API URL
          browserURL: "https://explorer.testnet.soniclabs.com", // Update with actual explorer URL
        },
      },
    ],
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
};

export default config;
```

### **1.4 Environment Variables Setup**

Create `.env` file in project root:

```bash
# Deployment wallet private key (DO NOT COMMIT)
PRIVATE_KEY=your_deployer_wallet_private_key

# Sonic testnet RPC URL
SONIC_RPC_URL=https://rpc.testnet.soniclabs.com

# Sonic block explorer API key (if available)
SONIC_EXPLORER_API_KEY=your_sonic_explorer_api_key

# Gas reporting (optional)
REPORT_GAS=true

# Frontend environment variables
NEXT_PUBLIC_SONIC_RPC_URL=https://rpc.testnet.soniclabs.com
NEXT_PUBLIC_CHAIN_ID=64165
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_wallet_connect_project_id
```

**⚠️ Security Note**: Add `.env` to `.gitignore` to prevent committing sensitive keys.

### **1.5 Deployment Scripts**

Create `scripts/deploy.ts`:

```typescript
import { ethers } from "hardhat";
import { Contract } from "ethers";

interface DeployedContracts {
  GameConfig: Contract;
  BattleshipToken: Contract;
  NFTManager: Contract;
  TokenomicsCore: Contract;
  StakingPool: Contract;
  MarketplaceCore: Contract;
  LootboxSystem: Contract;
  BattleshipGame: Contract;
}

async function main() {
  console.log("🚀 Starting CryptoBattleship V2 deployment to Sonic testnet...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  const contracts: Partial<DeployedContracts> = {};

  // 1. Deploy GameConfig
  console.log("\\n📋 Deploying GameConfig...");
  const GameConfig = await ethers.getContractFactory("GameConfig");
  contracts.GameConfig = await GameConfig.deploy();
  await contracts.GameConfig.waitForDeployment();
  console.log("GameConfig deployed to:", await contracts.GameConfig.getAddress());

  // 2. Deploy BattleshipToken
  console.log("\\n🪙 Deploying BattleshipToken...");
  const BattleshipToken = await ethers.getContractFactory("BattleshipToken");
  contracts.BattleshipToken = await BattleshipToken.deploy(
    "CryptoBattleship Token",
    "SHIP",
    ethers.parseEther("1000000000") // 1B max supply
  );
  await contracts.BattleshipToken.waitForDeployment();
  console.log("BattleshipToken deployed to:", await contracts.BattleshipToken.getAddress());

  // 3. Deploy NFTManager
  console.log("\\n🖼️ Deploying NFTManager...");
  const NFTManager = await ethers.getContractFactory("NFTManager");
  contracts.NFTManager = await NFTManager.deploy();
  await contracts.NFTManager.waitForDeployment();
  console.log("NFTManager deployed to:", await contracts.NFTManager.getAddress());

  // 4. Deploy TokenomicsCore (V2)
  console.log("\\n💰 Deploying TokenomicsCore V2...");
  const TokenomicsCore = await ethers.getContractFactory("TokenomicsCore");
  contracts.TokenomicsCore = await TokenomicsCore.deploy(
    await contracts.BattleshipToken.getAddress(),
    await contracts.GameConfig.getAddress()
  );
  await contracts.TokenomicsCore.waitForDeployment();
  console.log("TokenomicsCore deployed to:", await contracts.TokenomicsCore.getAddress());

  // 5. Deploy StakingPool (V2)
  console.log("\\n🔒 Deploying StakingPool V2...");
  const StakingPool = await ethers.getContractFactory("StakingPool");
  contracts.StakingPool = await StakingPool.deploy(
    await contracts.BattleshipToken.getAddress(),
    await contracts.TokenomicsCore.getAddress()
  );
  await contracts.StakingPool.waitForDeployment();
  console.log("StakingPool deployed to:", await contracts.StakingPool.getAddress());

  // 6. Deploy MarketplaceCore
  console.log("\\n🛒 Deploying MarketplaceCore...");
  const MarketplaceCore = await ethers.getContractFactory("MarketplaceCore");
  contracts.MarketplaceCore = await MarketplaceCore.deploy(
    await contracts.NFTManager.getAddress(),
    await contracts.BattleshipToken.getAddress(),
    await contracts.TokenomicsCore.getAddress()
  );
  await contracts.MarketplaceCore.waitForDeployment();
  console.log("MarketplaceCore deployed to:", await contracts.MarketplaceCore.getAddress());

  // 7. Deploy LootboxSystem
  console.log("\\n📦 Deploying LootboxSystem...");
  const LootboxSystem = await ethers.getContractFactory("LootboxSystem");
  contracts.LootboxSystem = await LootboxSystem.deploy(
    await contracts.NFTManager.getAddress(),
    await contracts.BattleshipToken.getAddress(),
    await contracts.TokenomicsCore.getAddress()
  );
  await contracts.LootboxSystem.waitForDeployment();
  console.log("LootboxSystem deployed to:", await contracts.LootboxSystem.getAddress());

  // 8. Deploy BattleshipGame
  console.log("\\n⚓ Deploying BattleshipGame...");
  const BattleshipGame = await ethers.getContractFactory("BattleshipGame");
  contracts.BattleshipGame = await BattleshipGame.deploy(
    await contracts.GameConfig.getAddress(),
    await contracts.NFTManager.getAddress(),
    await contracts.BattleshipToken.getAddress(),
    await contracts.TokenomicsCore.getAddress()
  );
  await contracts.BattleshipGame.waitForDeployment();
  console.log("BattleshipGame deployed to:", await contracts.BattleshipGame.getAddress());

  // Initial Configuration
  console.log("\\n⚙️ Configuring contracts...");
  
  // Set TokenomicsCore emission multiplier to 10%
  await contracts.TokenomicsCore.setEmissionRevenueMultiplier(10);
  console.log("✅ Set emission revenue multiplier to 10%");

  // Configure StakingPool with TokenomicsCore
  await contracts.StakingPool.updateContract("TokenomicsCore", await contracts.TokenomicsCore.getAddress());
  console.log("✅ Configured StakingPool with TokenomicsCore");

  // Grant minter role to TokenomicsCore for SHIP token
  const MINTER_ROLE = await contracts.BattleshipToken.MINTER_ROLE();
  await contracts.BattleshipToken.grantRole(MINTER_ROLE, await contracts.TokenomicsCore.getAddress());
  console.log("✅ Granted minter role to TokenomicsCore");

  // Output deployment summary
  console.log("\\n🎉 Deployment Complete!");
  console.log("\\n📄 Contract Addresses:");
  console.log("========================");
  for (const [name, contract] of Object.entries(contracts)) {
    console.log(\`\${name}: \${await contract!.getAddress()}\`);
  }

  console.log("\\n🔗 Save these addresses for frontend configuration!");
  
  // Save to file for easy reference
  const addresses = {};
  for (const [name, contract] of Object.entries(contracts)) {
    addresses[name] = await contract!.getAddress();
  }
  
  const fs = require('fs');
  fs.writeFileSync(
    './deployed-addresses.json', 
    JSON.stringify(addresses, null, 2)
  );
  console.log("\\n💾 Addresses saved to deployed-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

### **1.6 Verification Script**

Create `scripts/verify.ts`:

```typescript
import { run } from "hardhat";
import deployedAddresses from "../deployed-addresses.json";

async function main() {
  console.log("🔍 Verifying contracts on Sonic Explorer...");

  try {
    // Verify GameConfig
    await run("verify:verify", {
      address: deployedAddresses.GameConfig,
      constructorArguments: [],
    });

    // Verify BattleshipToken
    await run("verify:verify", {
      address: deployedAddresses.BattleshipToken,
      constructorArguments: [
        "CryptoBattleship Token",
        "SHIP", 
        "1000000000000000000000000000" // 1B tokens in wei
      ],
    });

    // Verify other contracts...
    // Add verification for each contract with proper constructor args

    console.log("✅ All contracts verified!");
  } catch (error) {
    console.error("❌ Verification failed:", error);
  }
}

main().catch(console.error);
```

---

## 🌐 **Phase 2: Frontend Configuration**

### **2.1 Web3 Dependencies**

Frontend already has these installed:
- `@rainbow-me/rainbowkit`
- `wagmi`
- `viem`
- `@tanstack/react-query`
- `ethers`

### **2.2 Sonic Network Configuration**

Create `frontend/src/config/chains.ts`:

```typescript
import { defineChain } from 'viem'

export const sonicTestnet = defineChain({
  id: 64165, // Update with actual Sonic testnet chain ID
  name: 'Sonic Testnet',
  network: 'sonic-testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'Sonic',
    symbol: 'S',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.testnet.soniclabs.com'], // Update with actual RPC URL
    },
    public: {
      http: ['https://rpc.testnet.soniclabs.com'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Sonic Explorer',
      url: 'https://explorer.testnet.soniclabs.com', // Update with actual explorer URL
    },
  },
  testnet: true,
})
```

### **2.3 Contract Configuration**

Create `frontend/src/config/contracts.ts`:

```typescript
export const CONTRACTS = {
  SONIC_TESTNET: {
    TokenomicsCore: "0x...", // From deployment
    StakingPool: "0x...",
    NFTManager: "0x...", 
    BattleshipToken: "0x...",
    BattleshipGame: "0x...",
    MarketplaceCore: "0x...",
    LootboxSystem: "0x...",
    GameConfig: "0x...",
  }
} as const

// Contract ABIs (extract from artifacts after compilation)
export const ABIS = {
  TokenomicsCore: [], // Import from artifacts
  StakingPool: [],
  NFTManager: [],
  BattleshipToken: [],
  // ... other ABIs
}
```

### **2.4 Wagmi Configuration**

Create `frontend/src/config/wagmi.ts`:

```typescript
'use client'

import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { sonicTestnet } from './chains'

export const wagmiConfig = getDefaultConfig({
  appName: 'CryptoBattleship',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || '',
  chains: [sonicTestnet],
  ssr: true,
})
```

### **2.5 Provider Setup**

Update `frontend/src/app/layout.tsx`:

```typescript
'use client'

import '@rainbow-me/rainbowkit/styles.css'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WagmiProvider } from 'wagmi'
import { RainbowKitProvider } from '@rainbow-me/rainbowkit'
import { wagmiConfig } from '@/config/wagmi'

const queryClient = new QueryClient()

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <WagmiProvider config={wagmiConfig}>
          <QueryClientProvider client={queryClient}>
            <RainbowKitProvider>
              {children}
            </RainbowKitProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  )
}
```

---

## 📝 **Phase 3: Information Gathering Checklist**

### **3.1 Sonic EVM Testnet Details Required**

- [ ] **Official RPC URL**: `https://rpc.testnet.soniclabs.com`
- [ ] **Chain ID**: Unique network identifier
- [ ] **Native Currency**: Name, symbol, decimals
- [ ] **Block Explorer URL**: For contract verification
- [ ] **Explorer API URL**: For contract verification
- [ ] **Faucet URL**: To obtain test tokens
- [ ] **Gas Price**: Typical gas price in gwei
- [ ] **Block Time**: Average block confirmation time

### **3.2 Wallet Setup Requirements**

- [ ] **Deployer Wallet**: 
  - Private key for deployment
  - Sufficient native tokens for gas
  - Recommended: 1+ tokens for deployment
- [ ] **MetaMask Configuration**:
  - Add Sonic testnet to MetaMask
  - Import/create test accounts
- [ ] **WalletConnect Project ID**: For RainbowKit integration

### **3.3 Testing Resources**

- [ ] **Test Tokens**: 
  - Native tokens from faucet
  - Mock ERC20s (USDC, USDT) for revenue testing
- [ ] **Frontend Hosting**: Vercel/Netlify account
- [ ] **Domain**: Optional custom domain for testing

---

## 🚀 **Phase 4: Deployment Execution**

### **4.1 Pre-Deployment Checklist**

- [ ] Hardhat configuration complete
- [ ] Environment variables set
- [ ] Deployer wallet funded
- [ ] Contracts compiled: `npx hardhat compile`
- [ ] Tests passing: `npx hardhat test`

### **4.2 Smart Contract Deployment**

```bash
# Compile contracts
npx hardhat compile

# Deploy to Sonic testnet
npx hardhat run scripts/deploy.ts --network sonic_testnet

# Verify contracts (optional)
npx hardhat run scripts/verify.ts --network sonic_testnet
```

### **4.3 Frontend Deployment**

```bash
# Navigate to frontend
cd frontend/

# Update contract addresses in config files
# (Use addresses from deployed-addresses.json)

# Build frontend
npm run build

# Deploy to Vercel
npx vercel --prod
# Or deploy to Netlify
npm run build && netlify deploy --prod --dir=.next
```

### **4.4 Initial Contract Configuration**

After deployment, configure contracts:

```bash
# Add revenue tokens to StakingPool
npx hardhat run scripts/configure.ts --network sonic_testnet
```

---

## 🧪 **Phase 5: Testing Protocol**

### **5.1 Smart Contract Testing**

#### **Basic Functionality**
- [ ] Deploy test ERC20 tokens (mock USDC, USDT)
- [ ] Mint initial SHIP tokens to test accounts
- [ ] Test basic staking with different lock periods
- [ ] Verify multiplier calculations (1x - 2x)

#### **V2 Features Testing**
- [ ] Configure emission revenue multiplier
- [ ] Record mock revenue in multiple tokens
- [ ] Trigger epoch processing (manual for testing)
- [ ] Test linear unlock mechanics
- [ ] Verify multi-token revenue distribution

#### **NFT System Testing**
- [ ] Mint different NFT types (Ships, Captains, Crew, Actions)
- [ ] Test on-chain SVG generation
- [ ] Verify attribute-based art rendering
- [ ] Test NFT marketplace functionality

### **5.2 Frontend Integration Testing**

#### **Web3 Connection**
- [ ] Connect MetaMask to Sonic testnet
- [ ] Switch networks automatically
- [ ] Handle connection errors gracefully

#### **Contract Interaction**
- [ ] Read contract data (balances, stakes, rewards)
- [ ] Execute transactions (stake, claim, mint)
- [ ] Display transaction status and confirmations
- [ ] Handle transaction errors

#### **UI/UX Testing**
- [ ] Dark theme displays correctly
- [ ] SVG NFT art loads and renders
- [ ] Real-time updates work
- [ ] Responsive design on mobile
- [ ] Loading states and error messages

### **5.3 End-to-End Scenarios**

#### **Staking Flow**
1. Connect wallet → Add SHIP tokens → Stake with lock period → View stake details → Wait for epoch → Claim rewards

#### **NFT Flow**  
2. Connect wallet → Mint NFT → View in fleet → See on-chain art → Use in game

#### **Revenue Flow**
3. Generate protocol revenue → Wait for epoch → Claim multi-token rewards → Verify linear unlock

---

## ⚠️ **Phase 6: Known Considerations & Troubleshooting**

### **6.1 Sonic-Specific Considerations**

#### **Network Configuration**
- Gas estimation may differ from Ethereum mainnet
- Block times may affect epoch timing calculations
- Native token handling for transaction fees

#### **Contract Verification**
- Explorer API may not be available initially
- Manual verification via explorer UI may be required
- Contract source code flattening for verification

### **6.2 Frontend Adjustments Needed**

#### **Replace Mock Data**
Current frontend uses mock data. Need to replace with real contract calls:
- `StakeForm.tsx`: Connect to actual staking contract
- `RewardsPanel.tsx`: Fetch real reward data
- `EpochProgress.tsx`: Get actual epoch information
- `SVGRenderer.tsx`: Call NFTManager.tokenURI()

#### **Transaction Handling**
- Add wagmi hooks for contract interactions
- Implement transaction confirmation UI
- Add proper error handling and retry logic
- Show gas estimation and transaction costs

#### **Real-time Updates**
- Implement contract event listeners
- Auto-refresh data after transactions
- Handle network disconnections
- Cache data for better UX

### **6.3 Common Issues & Solutions**

#### **Deployment Issues**
- **Out of gas**: Increase gas limit in hardhat config
- **Nonce too high**: Reset MetaMask account
- **Contract size**: Enable optimizer in Solidity settings

#### **Frontend Issues**  
- **Network not recognized**: Add network to wagmi config
- **Contract not found**: Verify addresses in config
- **Transaction fails**: Check contract permissions and balances

#### **Testing Issues**
- **Epoch not processing**: Manually trigger or check timing
- **SVG not loading**: Verify NFTManager contract deployment
- **Rewards not claiming**: Check linear unlock progress and balances

---

## 📋 **Phase 7: Post-Deployment Checklist**

### **7.1 Documentation Updates**
- [ ] Update README with testnet addresses
- [ ] Document any Sonic-specific configurations
- [ ] Create user guide for testnet interaction
- [ ] Record deployment transaction hashes

### **7.2 Monitoring Setup**
- [ ] Monitor contract events via explorer
- [ ] Set up alerts for failed transactions
- [ ] Track gas usage and optimization opportunities
- [ ] Monitor frontend performance and errors

### **7.3 Community Testing**
- [ ] Share testnet links with team/community
- [ ] Collect feedback on UI/UX
- [ ] Identify any network-specific issues
- [ ] Prepare for mainnet deployment

---

## 📞 **Support & Resources**

### **Sonic Labs Resources**
- **Documentation**: [Update with Sonic docs URL]
- **Discord**: [Sonic community Discord]
- **GitHub**: [Sonic Labs GitHub]
- **Faucet**: [Testnet faucet URL]

### **CryptoBattleship Resources**
- **V2 Documentation**: `./v2_upgrade_docs/`
- **Contract Reference**: `./CONTRACT_FUNCTIONS.md`
- **Migration Guide**: `./v2_upgrade_docs/MIGRATION_CHECKLIST.md`

---

**Status**: Ready for testnet deployment once Sonic EVM details are gathered and configured.

**Next Step**: Gather Sonic testnet configuration details and execute Phase 1 setup.