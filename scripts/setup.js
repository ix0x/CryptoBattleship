const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("⚙️ Setting up CryptoBattleship initial configuration...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Setup account:", deployer.address);
  
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
  
  // Get contract instances
  const gameConfig = await ethers.getContractAt("GameConfig", contracts.GameConfig);
  const shipNFTManager = await ethers.getContractAt("ShipNFTManager", contracts.ShipNFTManager);
  const actionNFTManager = await ethers.getContractAt("ActionNFTManager", contracts.ActionNFTManager);
  const captainAndCrewNFTManager = await ethers.getContractAt("CaptainAndCrewNFTManager", contracts.CaptainAndCrewNFTManager);
  const lootboxSystem = await ethers.getContractAt("LootboxSystem", contracts.LootboxSystem);
  const battleshipGame = await ethers.getContractAt("BattleshipGame", contracts.BattleshipGame);
  
  try {
    // 1. Configure GameConfig with initial parameters
    console.log("\n🎮 Configuring GameConfig...");
    
    // Set turn timer to 5 minutes (300 seconds)
    await gameConfig.updateTurnTimer(300);
    console.log("✅ Turn timer set to 5 minutes");
    
    // Set weekly emission rate to 10,000 SHIP tokens
    await gameConfig.updateWeeklyEmissionRate(ethers.parseEther("10000"));
    console.log("✅ Weekly emission rate set to 10,000 SHIP");
    
    // Set game fee to 5%
    await gameConfig.updateGameFeePercentage(5);
    console.log("✅ Game fee set to 5%");
    
    // 2. Add some action templates for testing
    console.log("\n⚔️ Adding default action templates...");
    
    // Add a cross pattern offensive action
    const crossPattern = [0, 1, 10, 11]; // 2x2 square pattern
    await actionNFTManager.addActionTemplate(
      "Cross Blast",           // name
      "Cross-shaped explosion", // description
      crossPattern,           // target cells
      2,                      // damage
      5,                      // range
      3,                      // uses
      0,                      // ActionCategory.OFFENSIVE
      0,                      // Rarity.COMMON
      false,                  // not seasonal only
      0                       // season 0 (all seasons)
    );
    console.log("✅ Added Cross Blast action template");
    
    // Add a line pattern offensive action
    const linePattern = [0, 1, 2]; // 3-cell line
    await actionNFTManager.addActionTemplate(
      "Line Shot",
      "Penetrating line attack",
      linePattern,
      1,                      // damage
      6,                      // range
      5,                      // uses
      0,                      // ActionCategory.OFFENSIVE
      1,                      // Rarity.UNCOMMON
      false,                  // not seasonal only
      0                       // season 0
    );
    console.log("✅ Added Line Shot action template");
    
    // Add a defensive shield action
    const shieldPattern = [0]; // Single cell
    await actionNFTManager.addActionTemplate(
      "Energy Shield",
      "Protective energy barrier",
      shieldPattern,
      0,                      // no damage (defensive)
      3,                      // range
      2,                      // uses
      1,                      // ActionCategory.DEFENSIVE
      0,                      // Rarity.COMMON
      false,                  // not seasonal only
      0                       // season 0
    );
    console.log("✅ Added Energy Shield action template");
    
    // 3. Assign templates to variant/rarity combinations
    console.log("\n📋 Assigning templates to variants...");
    
    // Assign Cross Blast to variant 0, OFFENSIVE, COMMON
    await actionNFTManager.assignTemplatesToVariantRarity(
      0, // variant 0 (classic)
      0, // ActionCategory.OFFENSIVE
      0, // Rarity.COMMON
      [2] // template ID 2 (Cross Blast)
    );
    
    // Assign Line Shot to variant 0, OFFENSIVE, UNCOMMON
    await actionNFTManager.assignTemplatesToVariantRarity(
      0, // variant 0
      0, // ActionCategory.OFFENSIVE
      1, // Rarity.UNCOMMON
      [3] // template ID 3 (Line Shot)
    );
    
    // Assign Energy Shield to variant 0, DEFENSIVE, COMMON
    await actionNFTManager.assignTemplatesToVariantRarity(
      0, // variant 0
      1, // ActionCategory.DEFENSIVE
      0, // Rarity.COMMON
      [4] // template ID 4 (Energy Shield)
    );
    
    console.log("✅ Templates assigned to variants");
    
    // 4. Set up lootbox pricing (10 SHIP tokens per lootbox - already set in constructor)
    console.log("\n📦 Lootbox system already configured with 10 SHIP per lootbox");
    
    // 5. Test the system by checking configs
    console.log("\n🧪 Testing configuration...");
    
    const turnTimer = await gameConfig.getTurnTimer();
    const emissionRate = await gameConfig.getWeeklyEmissionRate();
    const gameFee = await gameConfig.getGameFeePercentage();
    const requiredAnte = await battleshipGame.getRequiredAnte(1); // FISH size
    
    console.log(`✅ Turn timer: ${turnTimer} seconds`);
    console.log(`✅ Weekly emission: ${ethers.formatEther(emissionRate)} SHIP`);
    console.log(`✅ Game fee: ${gameFee}%`);
    console.log(`✅ Required ante: ${ethers.formatEther(requiredAnte)} S`);
    
    // 6. Create setup summary
    const setupSummary = {
      network: "sonicBlaze",
      chainId: 57054,
      setupTimestamp: new Date().toISOString(),
      configuration: {
        turnTimer: turnTimer.toString(),
        weeklyEmission: ethers.formatEther(emissionRate),
        gameFeePercentage: gameFee.toString(),
        anteAmount: ethers.formatEther(requiredAnte),
        lootboxPrice: "10 SHIP tokens",
        actionTemplatesAdded: 3,
        variantAssignments: 3
      },
      contracts: contracts,
      ready: true
    };
    
    fs.writeFileSync(
      'setup-complete-sonic-blaze.json',
      JSON.stringify(setupSummary, null, 2)
    );
    
    console.log("\n🎉 Setup completed successfully!");
    console.log("\n📋 System Status:");
    console.log("✅ All contracts deployed and configured");
    console.log("✅ NFT minting authorized for LootboxSystem and BattleshipGame");
    console.log("✅ Action templates created and assigned");
    console.log("✅ Game parameters configured");
    console.log("✅ Ante system set to 1S for testing");
    console.log("\n💾 Setup summary saved to setup-complete-sonic-blaze.json");
    
    console.log("\n🚀 Your CryptoBattleship deployment is now ready!");
    console.log("\n🎮 To test:");
    console.log("1. Create a game with 1S ante");
    console.log("2. Purchase lootboxes for 10 SHIP tokens");
    console.log("3. Use NFTs in battles");
    
    console.log("\n🌐 Explorer Links:");
    console.log(`Game Contract: https://testnet.sonicscan.org/address/${contracts.BattleshipGame}`);
    console.log(`Ship NFTs: https://testnet.sonicscan.org/address/${contracts.ShipNFTManager}`);
    console.log(`Lootbox System: https://testnet.sonicscan.org/address/${contracts.LootboxSystem}`);
    
  } catch (error) {
    console.error("❌ Setup failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Setup script failed:", error);
    process.exit(1);
  });