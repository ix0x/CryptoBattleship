const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🔍 Checking Lootbox Configuration");
  console.log("=================================");
  
  const [deployer] = await ethers.getSigners();
  console.log("Checking with account:", deployer.address);
  
  // Contract addresses
  const addresses = {
    BattleshipToken: "0x49Dcf31d2e807F2DdC25357EBaE1C40EC29aF6Cd",
    LootboxSystem: "0x3Bb7Ae609779A8393A0A96d0F4516E813D857C4E"
  };
  
  try {
    // Get contract instances
    const battleshipToken = await ethers.getContractAt("BattleshipToken", addresses.BattleshipToken);
    const lootboxSystem = await ethers.getContractAt("LootboxSystem", addresses.LootboxSystem);
    
    console.log("\n💰 Token Information:");
    const playerBalance = await battleshipToken.balanceOf(deployer.address);
    console.log(`Player SHIP Balance: ${ethers.formatEther(playerBalance)}`);
    
    console.log("\n📦 Lootbox System Configuration:");
    
    // Check if lootbox price is set
    try {
      const lootboxPrice = await lootboxSystem.lootboxPrices(addresses.BattleshipToken);
      console.log(`Lootbox price: ${ethers.formatEther(lootboxPrice)} SHIP`);
    } catch (error) {
      console.log("❌ Lootbox price not set or error:", error.message);
    }
    
    // Check allowance
    const allowance = await battleshipToken.allowance(deployer.address, addresses.LootboxSystem);
    console.log(`Current allowance: ${ethers.formatEther(allowance)} SHIP`);
    
    // Check if we need to set lootbox price
    console.log("\n🔧 Setting lootbox price...");
    const lootboxPriceToSet = ethers.parseEther("10"); // 10 SHIP tokens
    await lootboxSystem.setLootboxPrice(addresses.BattleshipToken, lootboxPriceToSet);
    console.log("✅ Lootbox price set to 10 SHIP tokens");
    
    // Verify the price was set
    const newPrice = await lootboxSystem.lootboxPrices(addresses.BattleshipToken);
    console.log(`Verified price: ${ethers.formatEther(newPrice)} SHIP`);
    
    console.log("\n🎉 Lootbox system is now properly configured!");
    
  } catch (error) {
    console.error("❌ Configuration check failed:", error);
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