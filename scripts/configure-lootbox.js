const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🎁 Configuring Lootbox Templates");
  console.log("================================");
  
  const [deployer] = await ethers.getSigners();
  console.log("Configuring with account:", deployer.address);
  
  // Contract addresses
  const lootboxSystemAddress = "0x3Bb7Ae609779A8393A0A96d0F4516E813D857C4E";
  
  // Get LootboxSystem contract
  const lootboxSystem = await ethers.getContractAt("LootboxSystem", lootboxSystemAddress);
  
  try {
    console.log("\n🚢 Adding Ship Templates...");
    // Add some basic ship templates (Common rarity = 0)
    await lootboxSystem.addLootTemplate(0, 0, 1, 1); // NFTType.SHIP, Common, shipTypeId=1, variantId=1
    await lootboxSystem.addLootTemplate(0, 0, 2, 1); // NFTType.SHIP, Common, shipTypeId=2, variantId=1
    await lootboxSystem.addLootTemplate(0, 0, 3, 1); // NFTType.SHIP, Common, shipTypeId=3, variantId=1
    console.log("✅ Added 3 common ship templates");
    
    console.log("\n⚔️ Adding Action Templates...");
    // Add some basic action templates
    await lootboxSystem.addLootTemplate(1, 0, 1, 1); // NFTType.ACTION, Common, actionId=1, variantId=1
    await lootboxSystem.addLootTemplate(1, 0, 2, 1); // NFTType.ACTION, Common, actionId=2, variantId=1
    console.log("✅ Added 2 common action templates");
    
    console.log("\n👑 Adding Captain Templates...");
    // Add captain templates
    await lootboxSystem.addLootTemplate(2, 0, 1, 1); // NFTType.CAPTAIN, Common, captainId=1, variantId=1
    await lootboxSystem.addLootTemplate(2, 1, 2, 1); // NFTType.CAPTAIN, Rare, captainId=2, variantId=1
    console.log("✅ Added 2 captain templates (1 common, 1 rare)");
    
    console.log("\n👥 Adding Crew Templates...");
    // Add crew templates for different types
    await lootboxSystem.addLootTemplate(3, 0, 0, 1); // NFTType.CREW, Common, crewType=GUNNER(0), variantId=1
    await lootboxSystem.addLootTemplate(3, 0, 1, 1); // NFTType.CREW, Common, crewType=NAVIGATOR(1), variantId=1
    await lootboxSystem.addLootTemplate(3, 0, 2, 1); // NFTType.CREW, Common, crewType=ENGINEER(2), variantId=1
    await lootboxSystem.addLootTemplate(3, 1, 3, 1); // NFTType.CREW, Rare, crewType=MEDIC(3), variantId=1
    console.log("✅ Added 4 crew templates (3 common, 1 rare)");
    
    console.log("\n🎯 Setting Drop Rates...");
    // Set drop rates: [common, rare, epic, legendary] = [70%, 25%, 4%, 1%]
    await lootboxSystem.setDropRates([7000, 2500, 400, 100]);
    console.log("✅ Set drop rates: 70% common, 25% rare, 4% epic, 1% legendary");
    
    console.log("\n🔍 Verifying Configuration...");
    const dropRates = await lootboxSystem.getDropRates();
    console.log("Drop rates:", dropRates.map(rate => (Number(rate) / 100).toFixed(1) + "%"));
    
    // Get template counts
    const shipTemplates = await lootboxSystem.getTemplateCount(0, 0); // Ships, Common
    const actionTemplates = await lootboxSystem.getTemplateCount(1, 0); // Actions, Common
    const captainTemplatesCommon = await lootboxSystem.getTemplateCount(2, 0); // Captains, Common
    const captainTemplatesRare = await lootboxSystem.getTemplateCount(2, 1); // Captains, Rare
    const crewTemplatesCommon = await lootboxSystem.getTemplateCount(3, 0); // Crew, Common
    const crewTemplatesRare = await lootboxSystem.getTemplateCount(3, 1); // Crew, Rare
    
    console.log("\n📊 Template Counts:");
    console.log(`🚢 Ships (Common): ${shipTemplates}`);
    console.log(`⚔️ Actions (Common): ${actionTemplates}`);
    console.log(`👑 Captains (Common): ${captainTemplatesCommon}, (Rare): ${captainTemplatesRare}`);
    console.log(`👥 Crew (Common): ${crewTemplatesCommon}, (Rare): ${crewTemplatesRare}`);
    
    console.log("\n🎉 Lootbox system fully configured!");
    console.log("Players can now successfully open lootboxes and receive NFTs!");
    
  } catch (error) {
    console.error("❌ Configuration failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Configuration script failed:", error);
    process.exit(1);
  });