const { run } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🔍 Starting contract verification on Sonic Blaze...");
  
  // Load deployment results
  const fs = require('fs');
  let deploymentData;
  
  try {
    deploymentData = JSON.parse(fs.readFileSync('deployment-sonic-blaze.json', 'utf8'));
  } catch (error) {
    console.error("❌ Could not load deployment-sonic-blaze.json");
    console.error("Please run deployment first: npm run deploy:sonic");
    process.exit(1);
  }
  
  const contracts = deploymentData.contracts;
  const INITIAL_ADMIN = process.env.INITIAL_ADMIN || deploymentData.deployer;
  const TEAM_TREASURY = process.env.TEAM_TREASURY || deploymentData.deployer;
  
  const verifications = [
    {
      name: "BattleshipToken",
      address: contracts.BattleshipToken,
      constructorArguments: [INITIAL_ADMIN]
    },
    {
      name: "GameConfig", 
      address: contracts.GameConfig,
      constructorArguments: [INITIAL_ADMIN]
    },
    {
      name: "ShipNFTManager",
      address: contracts.ShipNFTManager,
      constructorArguments: [INITIAL_ADMIN]
    },
    {
      name: "ActionNFTManager",
      address: contracts.ActionNFTManager,
      constructorArguments: [INITIAL_ADMIN]
    },
    {
      name: "CaptainAndCrewNFTManager",
      address: contracts.CaptainAndCrewNFTManager,
      constructorArguments: [INITIAL_ADMIN]
    },
    {
      name: "StakingPool",
      address: contracts.StakingPool,
      constructorArguments: [contracts.BattleshipToken, INITIAL_ADMIN]
    },
    {
      name: "TokenomicsCore",
      address: contracts.TokenomicsCore,
      constructorArguments: [
        contracts.BattleshipToken,
        contracts.GameConfig,
        contracts.ShipNFTManager,
        TEAM_TREASURY
      ]
    },
    {
      name: "BattleshipGame",
      address: contracts.BattleshipGame,
      constructorArguments: [
        INITIAL_ADMIN,
        contracts.ShipNFTManager,
        contracts.ActionNFTManager,
        contracts.CaptainAndCrewNFTManager
      ]
    },
    {
      name: "LootboxSystem",
      address: contracts.LootboxSystem,
      constructorArguments: [
        contracts.BattleshipToken,
        contracts.TokenomicsCore,
        contracts.ShipNFTManager,
        contracts.ActionNFTManager,
        contracts.CaptainAndCrewNFTManager,
        contracts.GameConfig
      ]
    }
  ];
  
  for (const contract of verifications) {
    try {
      console.log(`\n🔍 Verifying ${contract.name} at ${contract.address}...`);
      
      await run("verify:verify", {
        address: contract.address,
        constructorArguments: contract.constructorArguments,
      });
      
      console.log(`✅ ${contract.name} verified successfully`);
      
    } catch (error) {
      if (error.message.toLowerCase().includes("already verified")) {
        console.log(`✅ ${contract.name} already verified`);
      } else {
        console.error(`❌ Failed to verify ${contract.name}:`, error.message);
      }
    }
    
    // Wait a bit between verifications to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  
  console.log("\n🎉 Verification process completed!");
  console.log("\n🌐 View contracts on Sonic Explorer:");
  Object.entries(contracts).forEach(([name, address]) => {
    console.log(`${name}: https://testnet.sonicscan.org/address/${address}`);
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Verification failed:", error);
    process.exit(1);
  });