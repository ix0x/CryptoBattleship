const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🎯 Setting Lootbox Drop Rates for Testing");
  console.log("=========================================");
  
  const [deployer] = await ethers.getSigners();
  console.log("Configuring with account:", deployer.address);
  
  const lootboxSystemAddress = "0x3Bb7Ae609779A8393A0A96d0F4516E813D857C4E";
  const lootboxSystem = await ethers.getContractAt("LootboxSystem", lootboxSystemAddress);
  
  try {
    console.log("\n🎰 Setting high drop rates for testing...");
    
    // Set high drop rates to guarantee captains and crew for testing
    // Ships are guaranteed (100%), others are configurable
    await lootboxSystem.setActionDropRate(8000); // 80% chance for first action
    await lootboxSystem.setBonusActionDropRate(5000); // 50% chance for bonus action
    await lootboxSystem.setCaptainDropRate(9000); // 90% chance for captain (high for testing)
    await lootboxSystem.setCrewDropRate(7000); // 70% chance for crew
    
    console.log("✅ Drop rates updated:");
    console.log("  🚢 Ships: 100% (guaranteed)");
    console.log("  ⚔️ Actions: 80% + 50% bonus");
    console.log("  👑 Captains: 90%");
    console.log("  👥 Crew: 70%");
    
    // Verify the rates
    const actionRate = await lootboxSystem.actionDropRate();
    const bonusActionRate = await lootboxSystem.bonusActionDropRate();
    const captainRate = await lootboxSystem.captainDropRate();
    const crewRate = await lootboxSystem.crewDropRate();
    
    console.log("\n🔍 Verified drop rates:");
    console.log(`⚔️ Action: ${Number(actionRate)/100}%`);
    console.log(`⚔️ Bonus Action: ${Number(bonusActionRate)/100}%`);
    console.log(`👑 Captain: ${Number(captainRate)/100}%`);
    console.log(`👥 Crew: ${Number(crewRate)/100}%`);
    
    console.log("\n🎉 Lootbox drop rates optimized for testing!");
    console.log("Players should now regularly get captains and crew from lootboxes!");
    
  } catch (error) {
    console.error("❌ Configuration failed:", error);
    console.error("Error details:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Script failed:", error);
    process.exit(1);
  });