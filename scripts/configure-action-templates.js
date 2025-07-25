const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("⚔️ Configuring Action Templates");
  console.log("===============================");
  
  const [deployer] = await ethers.getSigners();
  console.log("Configuring with account:", deployer.address);
  
  // Contract address
  const actionNFTManagerAddress = "0xF339ff707Ee7Ced2b4F1823A3C4a069D23AFA56A";
  
  // Get ActionNFTManager contract
  const actionNFTManager = await ethers.getContractAt("ActionNFTManager", actionNFTManagerAddress);
  
  try {
    console.log("\n🔫 Adding Offensive Action Templates...");
    
    // Common offensive actions
    await actionNFTManager.addActionTemplate(
      "Rapid Fire",
      "Quick burst attack",
      [0, 1], // 2 cells
      1, // damage
      4, // range
      5, // uses
      0, // OFFENSIVE
      0, // COMMON
      false, // isSeasonalOnly
      0 // seasonId
    );
    console.log("✅ Added Rapid Fire (Common)");
    
    // Define cells for cross pattern attack
    const crossPattern = [0, 1, 2, 3, 4]; // Cross pattern: center + 4 adjacent
    await actionNFTManager.addActionTemplate(
      "Cross Barrage",
      "Cross-pattern attack",
      crossPattern,
      2, // damage
      6, // range
      2, // uses
      0, // OFFENSIVE
      1, // RARE
      false, // isSeasonalOnly
      0 // seasonId
    );
    console.log("✅ Added Cross Barrage (Rare)");
    
    console.log("\n🛡️ Adding Defensive Action Templates...");
    
    // Common defensive action
    await actionNFTManager.addActionTemplate(
      "Shield Boost",
      "Temporary shield enhancement",
      [0], // Self-target
      0, // damage
      0, // range
      3, // uses
      1, // DEFENSIVE
      0, // COMMON
      false, // isSeasonalOnly
      0 // seasonId
    );
    console.log("✅ Added Shield Boost (Common)");
    
    // Rare defensive action
    await actionNFTManager.addActionTemplate(
      "Emergency Repair",
      "Rapid hull repair system",
      [0], // Self-target
      0, // damage
      0, // range
      1, // uses
      1, // DEFENSIVE
      1, // RARE
      false, // isSeasonalOnly
      0 // seasonId
    );
    console.log("✅ Added Emergency Repair (Rare)");
    
    console.log("\n🎯 Updating Template Assignments...");
    
    // Get the next template ID (should be around 5-6 now)
    const nextTemplateId = await actionNFTManager.nextTemplateId();
    console.log(`Next template ID: ${nextTemplateId}`);
    
    // Update variant assignments for different rarities
    // For classic variant (0), we need to assign templates to each rarity/category combo
    console.log("Setting up template assignments for classic variant...");
    
    // OFFENSIVE COMMON: templates 1, 2 (Basic Shot from init + Rapid Fire)
    await actionNFTManager.assignTemplatesToVariantRarity(0, 0, 0, [1, 2]); // variant=0, category=OFFENSIVE, rarity=COMMON, templates=[1,2]
    
    // OFFENSIVE RARE: template 3 (Cross Barrage)
    await actionNFTManager.assignTemplatesToVariantRarity(0, 0, 1, [3]); // variant=0, category=OFFENSIVE, rarity=RARE, templates=[3]
    
    // DEFENSIVE COMMON: template 4 (Shield Boost)
    await actionNFTManager.assignTemplatesToVariantRarity(0, 1, 0, [4]); // variant=0, category=DEFENSIVE, rarity=COMMON, templates=[4]
    
    // DEFENSIVE RARE: template 5 (Emergency Repair)
    await actionNFTManager.assignTemplatesToVariantRarity(0, 1, 1, [5]); // variant=0, category=DEFENSIVE, rarity=RARE, templates=[5]
    
    console.log("✅ Template assignments updated");
    
    console.log("\n🔍 Verifying Configuration...");
    
    // Check template assignments using public mapping
    const offensiveCommon = await actionNFTManager.variantTemplatesByRarity(0, 0, 0); // variant=0, OFFENSIVE=0, COMMON=0
    const offensiveRare = await actionNFTManager.variantTemplatesByRarity(0, 0, 1); // variant=0, OFFENSIVE=0, RARE=1
    const defensiveCommon = await actionNFTManager.variantTemplatesByRarity(0, 1, 0); // variant=0, DEFENSIVE=1, COMMON=0
    const defensiveRare = await actionNFTManager.variantTemplatesByRarity(0, 1, 1); // variant=0, DEFENSIVE=1, RARE=1
    
    console.log("📊 Template Assignments:");
    console.log(`🔫 Offensive Common: [${offensiveCommon.join(', ')}]`);
    console.log(`🔫 Offensive Rare: [${offensiveRare.join(', ')}]`);
    console.log(`🛡️ Defensive Common: [${defensiveCommon.join(', ')}]`);
    console.log(`🛡️ Defensive Rare: [${defensiveRare.join(', ')}]`);
    
    console.log("\n🎉 Action templates fully configured!");
    console.log("ActionNFTManager can now mint all action types successfully!");
    
  } catch (error) {
    console.error("❌ Configuration failed:", error);
    console.error("Error details:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Configuration script failed:", error);
    process.exit(1);
  });