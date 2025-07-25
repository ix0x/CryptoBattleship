const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🎰 Fixing Lootbox Drop Rates");
  console.log("============================");
  
  const [deployer] = await ethers.getSigners();
  console.log("Updating with account:", deployer.address);
  
  const lootboxSystemAddress = "0x3Bb7Ae609779A8393A0A96d0F4516E813D857C4E";
  const lootboxSystem = await ethers.getContractAt("LootboxSystem", lootboxSystemAddress);
  
  try {
    console.log("\n📊 Current Drop Rates:");
    const currentActionRate = await lootboxSystem.actionDropRate();
    const currentBonusActionRate = await lootboxSystem.bonusActionDropRate();
    const currentCaptainRate = await lootboxSystem.captainDropRate();
    const currentCrewRate = await lootboxSystem.crewDropRate();
    
    console.log(`⚔️ Actions: ${Number(currentActionRate)/100}% + ${Number(currentBonusActionRate)/100}% bonus`);
    console.log(`👑 Captains: ${Number(currentCaptainRate)/100}%`);
    console.log(`👥 Crew: ${Number(currentCrewRate)/100}%`);
    
    console.log("\n🔧 Setting proper drop rates for 5 NFTs per lootbox...");
    
    // Set rates for guaranteed drops that give ~5 NFTs per lootbox:
    // - Ships: 100% (guaranteed) = 1 NFT
    // - Actions: 95% first + 85% bonus = ~1.8 NFTs average  
    // - Captains: 90% = 0.9 NFTs average
    // - Crew: 85% = 0.85 NFTs average
    // Total: ~4.55 NFTs average (good for testing)
    
    const shipRates = [10000, 0, 0, 0]; // Ships guaranteed (10000 = 100%)
    const actionRates = [9500, 8500, 0, 0]; // 95% first action, 85% bonus action
    const captainRate = 9000; // 90% chance for captain
    const crewRate = 8500; // 85% chance for crew
    
    await lootboxSystem.updateDropRates(shipRates, actionRates, captainRate, crewRate);
    
    console.log("✅ Updated drop rates:");
    console.log("  🚢 Ships: 100% (guaranteed)");
    console.log("  ⚔️ Actions: 95% + 85% bonus");
    console.log("  👑 Captains: 90%");
    console.log("  👥 Crew: 85%");
    
    // Verify the new rates
    console.log("\n🔍 Verifying new rates:");
    const newActionRate = await lootboxSystem.actionDropRate();
    const newBonusActionRate = await lootboxSystem.bonusActionDropRate();
    const newCaptainRate = await lootboxSystem.captainDropRate();
    const newCrewRate = await lootboxSystem.crewDropRate();
    
    console.log(`⚔️ Actions: ${Number(newActionRate)/100}% + ${Number(newBonusActionRate)/100}% bonus`);
    console.log(`👑 Captains: ${Number(newCaptainRate)/100}%`);
    console.log(`👥 Crew: ${Number(newCrewRate)/100}%`);
    
    const expectedAvg = 1 + (9500/10000) + (8500/10000) + (9000/10000) + (8500/10000);
    console.log(`\n📈 Expected average NFTs per lootbox: ${expectedAvg.toFixed(2)}`);
    
    console.log("\n🎉 Lootbox drop rates fixed!");
    console.log("Players should now get ~4-5 NFTs per lootbox including captains!");
    
  } catch (error) {
    console.error("❌ Update failed:", error);
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