const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("🚀 Deploying CryptoBattleship to Sonic Blaze Testnet");
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());
  
  // Configuration
  const INITIAL_ADMIN = process.env.INITIAL_ADMIN || deployer.address;
  const TEAM_TREASURY = process.env.TEAM_TREASURY || deployer.address;
  
  console.log("Admin address:", INITIAL_ADMIN);
  console.log("Team treasury:", TEAM_TREASURY);
  
  const deploymentResults = {};
  
  try {
    // 1. Deploy BattleshipToken
    console.log("\n📄 Deploying BattleshipToken...");
    const BattleshipToken = await ethers.getContractFactory("BattleshipToken");
    const battleshipToken = await BattleshipToken.deploy(INITIAL_ADMIN);
    await battleshipToken.waitForDeployment();
    const battleshipTokenAddress = await battleshipToken.getAddress();
    deploymentResults.BattleshipToken = battleshipTokenAddress;
    console.log("✅ BattleshipToken deployed to:", battleshipTokenAddress);
    
    // 2. Deploy GameConfig
    console.log("\n⚙️ Deploying GameConfig...");
    const GameConfig = await ethers.getContractFactory("GameConfig");
    const gameConfig = await GameConfig.deploy(INITIAL_ADMIN);
    await gameConfig.waitForDeployment();
    const gameConfigAddress = await gameConfig.getAddress();
    deploymentResults.GameConfig = gameConfigAddress;
    console.log("✅ GameConfig deployed to:", gameConfigAddress);
    
    // 3. Deploy Split NFT Managers
    console.log("\n🚢 Deploying ShipNFTManager...");
    const ShipNFTManager = await ethers.getContractFactory("ShipNFTManager");
    const shipNFTManager = await ShipNFTManager.deploy(INITIAL_ADMIN);
    await shipNFTManager.waitForDeployment();
    const shipNFTManagerAddress = await shipNFTManager.getAddress();
    deploymentResults.ShipNFTManager = shipNFTManagerAddress;
    console.log("✅ ShipNFTManager deployed to:", shipNFTManagerAddress);
    
    console.log("\n⚔️ Deploying ActionNFTManager...");
    const ActionNFTManager = await ethers.getContractFactory("ActionNFTManager");
    const actionNFTManager = await ActionNFTManager.deploy(INITIAL_ADMIN);
    await actionNFTManager.waitForDeployment();
    const actionNFTManagerAddress = await actionNFTManager.getAddress();
    deploymentResults.ActionNFTManager = actionNFTManagerAddress;
    console.log("✅ ActionNFTManager deployed to:", actionNFTManagerAddress);
    
    console.log("\n👥 Deploying CaptainAndCrewNFTManager...");
    const CaptainAndCrewNFTManager = await ethers.getContractFactory("CaptainAndCrewNFTManager");
    const captainAndCrewNFTManager = await CaptainAndCrewNFTManager.deploy(INITIAL_ADMIN);
    await captainAndCrewNFTManager.waitForDeployment();
    const captainAndCrewNFTManagerAddress = await captainAndCrewNFTManager.getAddress();
    deploymentResults.CaptainAndCrewNFTManager = captainAndCrewNFTManagerAddress;
    console.log("✅ CaptainAndCrewNFTManager deployed to:", captainAndCrewNFTManagerAddress);
    
    // 4. Deploy StakingPool
    console.log("\n💰 Deploying StakingPool...");
    const StakingPool = await ethers.getContractFactory("StakingPool");
    const stakingPool = await StakingPool.deploy(battleshipTokenAddress, INITIAL_ADMIN);
    await stakingPool.waitForDeployment();
    const stakingPoolAddress = await stakingPool.getAddress();
    deploymentResults.StakingPool = stakingPoolAddress;
    console.log("✅ StakingPool deployed to:", stakingPoolAddress);
    
    // 5. Deploy TokenomicsCore
    console.log("\n💎 Deploying TokenomicsCore...");
    const TokenomicsCore = await ethers.getContractFactory("TokenomicsCore");
    const tokenomicsCore = await TokenomicsCore.deploy(
      battleshipTokenAddress,
      gameConfigAddress,
      shipNFTManagerAddress, // Updated to use ShipNFTManager
      TEAM_TREASURY
    );
    await tokenomicsCore.waitForDeployment();
    const tokenomicsCoreAddress = await tokenomicsCore.getAddress();
    deploymentResults.TokenomicsCore = tokenomicsCoreAddress;
    console.log("✅ TokenomicsCore deployed to:", tokenomicsCoreAddress);
    
    // 6. Deploy BattleshipGame
    console.log("\n🎮 Deploying BattleshipGame...");
    const BattleshipGame = await ethers.getContractFactory("BattleshipGame");
    const battleshipGame = await BattleshipGame.deploy(
      INITIAL_ADMIN,
      shipNFTManagerAddress,
      actionNFTManagerAddress,
      captainAndCrewNFTManagerAddress
    );
    await battleshipGame.waitForDeployment();
    const battleshipGameAddress = await battleshipGame.getAddress();
    deploymentResults.BattleshipGame = battleshipGameAddress;
    console.log("✅ BattleshipGame deployed to:", battleshipGameAddress);
    
    // 7. Deploy LootboxSystem
    console.log("\n📦 Deploying LootboxSystem...");
    const LootboxSystem = await ethers.getContractFactory("LootboxSystem");
    const lootboxSystem = await LootboxSystem.deploy(
      battleshipTokenAddress,
      tokenomicsCoreAddress,
      shipNFTManagerAddress,
      actionNFTManagerAddress,
      captainAndCrewNFTManagerAddress,
      gameConfigAddress
    );
    await lootboxSystem.waitForDeployment();
    const lootboxSystemAddress = await lootboxSystem.getAddress();
    deploymentResults.LootboxSystem = lootboxSystemAddress;
    console.log("✅ LootboxSystem deployed to:", lootboxSystemAddress);
    
    // 8. Set up contract integrations
    console.log("\n🔧 Setting up contract integrations...");
    
    // Set BattleshipGame contract addresses
    console.log("Setting BattleshipGame contract addresses...");
    await battleshipGame.setContractAddresses(
      gameConfigAddress,
      shipNFTManagerAddress,
      actionNFTManagerAddress,
      captainAndCrewNFTManagerAddress,
      tokenomicsCoreAddress
    );
    
    // Set authorized minters
    console.log("Setting up authorized minters...");
    await shipNFTManager.setAuthorizedMinter(lootboxSystemAddress, true);
    await actionNFTManager.setAuthorizedMinter(lootboxSystemAddress, true);
    await captainAndCrewNFTManager.setAuthorizedMinter(lootboxSystemAddress, true);
    
    // Set BattleshipGame as authorized for ship operations
    await shipNFTManager.setAuthorizedMinter(battleshipGameAddress, true);
    await actionNFTManager.setAuthorizedMinter(battleshipGameAddress, true);
    await captainAndCrewNFTManager.setAuthorizedMinter(battleshipGameAddress, true);
    
    // Set TokenomicsCore authorized minters
    await tokenomicsCore.setAuthorizedMinter(battleshipGameAddress, true);
    await tokenomicsCore.setAuthorizedMinter(lootboxSystemAddress, true);
    
    // Set BattleshipToken minter
    await battleshipToken.setMinter(tokenomicsCoreAddress, true);
    
    console.log("\n🎉 Deployment completed successfully!");
    console.log("\n📋 Contract Addresses:");
    Object.entries(deploymentResults).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });
    
    // Save deployment results
    const fs = require('fs');
    const deploymentData = {
      network: "sonicBlaze",
      chainId: 57054,
      timestamp: new Date().toISOString(),
      deployer: deployer.address,
      contracts: deploymentResults
    };
    
    fs.writeFileSync(
      'deployment-sonic-blaze.json',
      JSON.stringify(deploymentData, null, 2)
    );
    console.log("\n💾 Deployment results saved to deployment-sonic-blaze.json");
    
    console.log("\n🔍 Next steps:");
    console.log("1. Verify contracts: npm run verify:sonic");
    console.log("2. Set up initial configuration: npm run setup:sonic");
    console.log("3. Test the deployment with the frontend");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment script failed:", error);
    process.exit(1);
  });