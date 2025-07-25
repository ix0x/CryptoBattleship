const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("📦 Simple Lootbox Test");
  console.log("======================");
  
  const [deployer] = await ethers.getSigners();
  console.log("Testing with account:", deployer.address);
  
  // Contract addresses
  const addresses = {
    BattleshipToken: "0x49Dcf31d2e807F2DdC25357EBaE1C40EC29aF6Cd",
    LootboxSystem: "0x3Bb7Ae609779A8393A0A96d0F4516E813D857C4E",
    ShipNFTManager: "0x90932BC326bCc7eb61007E373648bE6352E71a90",
    ActionNFTManager: "0xF339ff707Ee7Ced2b4F1823A3C4a069D23AFA56A",
    CaptainNFTManager: "0xFa5b0033df93a2c5c0CDc7374d88Bd4a824032f2",
    CrewNFTManager: "0x17e9BDFD27FFd16Bf7543180534dF28f8F64d998"
  };
  
  try {
    // Get contract instances
    const battleshipToken = await ethers.getContractAt("BattleshipToken", addresses.BattleshipToken);
    const lootboxSystem = await ethers.getContractAt("LootboxSystem", addresses.LootboxSystem);
    const shipNFTManager = await ethers.getContractAt("ShipNFTManager", addresses.ShipNFTManager);
    const actionNFTManager = await ethers.getContractAt("ActionNFTManager", addresses.ActionNFTManager);
    const captainNFTManager = await ethers.getContractAt("CaptainNFTManager", addresses.CaptainNFTManager);
    const crewNFTManager = await ethers.getContractAt("CrewNFTManager", addresses.CrewNFTManager);
    
    console.log("\n💰 Current Status:");
    const balance = await battleshipToken.balanceOf(deployer.address);
    const allowance = await battleshipToken.allowance(deployer.address, addresses.LootboxSystem);
    const lootboxPrice = await lootboxSystem.lootboxPrices(addresses.BattleshipToken);
    
    console.log(`SHIP Balance: ${ethers.formatEther(balance)}`);
    console.log(`Allowance: ${ethers.formatEther(allowance)}`);
    console.log(`Lootbox Price: ${ethers.formatEther(lootboxPrice)}`);
    
    // Check NFT balances before
    const shipsBefore = await shipNFTManager.balanceOf(deployer.address);
    const actionsBefore = await actionNFTManager.balanceOf(deployer.address);
    const captainsBefore = await captainNFTManager.balanceOf(deployer.address);
    const crewBefore = await crewNFTManager.balanceOf(deployer.address);
    
    console.log("\n🎯 NFTs Before:");
    console.log(`Ships: ${shipsBefore}, Actions: ${actionsBefore}, Captains: ${captainsBefore}, Crew: ${crewBefore}`);
    
    // Ensure sufficient allowance
    if (allowance < lootboxPrice) {
      console.log("\n💳 Setting allowance...");
      await battleshipToken.approve(addresses.LootboxSystem, ethers.parseEther("1000"));
      console.log("✅ Allowance set");
    }
    
    // Buy lootbox
    console.log("\n📦 Buying lootbox...");
    const buyTx = await lootboxSystem.buyLootbox(addresses.BattleshipToken, lootboxPrice);
    const buyReceipt = await buyTx.wait();
    
    // Get lootbox ID from event
    let lootboxId = 3; // Fallback
    for (const log of buyReceipt.logs) {
      try {
        const parsed = lootboxSystem.interface.parseLog(log);
        if (parsed.name === "LootboxPurchased") {
          lootboxId = parsed.args[1];
          break;
        }
      } catch (e) { /* ignore parsing errors */ }
    }
    
    console.log(`✅ Bought lootbox #${lootboxId}`);
    
    // Open lootbox
    console.log("\n🎁 Opening lootbox...");
    const openTx = await lootboxSystem.openLootbox(lootboxId);
    const openReceipt = await openTx.wait();
    
    console.log("✅ Lootbox opened!");
    
    // Check NFT balances after
    const shipsAfter = await shipNFTManager.balanceOf(deployer.address);
    const actionsAfter = await actionNFTManager.balanceOf(deployer.address);
    const captainsAfter = await captainNFTManager.balanceOf(deployer.address);
    const crewAfter = await crewNFTManager.balanceOf(deployer.address);
    
    console.log("\n🎯 NFTs After:");
    console.log(`Ships: ${shipsAfter}, Actions: ${actionsAfter}, Captains: ${captainsAfter}, Crew: ${crewAfter}`);
    
    const totalBefore = Number(shipsBefore) + Number(actionsBefore) + Number(captainsBefore) + Number(crewBefore);
    const totalAfter = Number(shipsAfter) + Number(actionsAfter) + Number(captainsAfter) + Number(crewAfter);
    const nftsReceived = totalAfter - totalBefore;
    
    console.log("\n📊 Results:");
    console.log(`🎁 Total NFTs received: ${nftsReceived}`);
    console.log(`🚢 Ships gained: ${Number(shipsAfter) - Number(shipsBefore)}`);
    console.log(`⚔️ Actions gained: ${Number(actionsAfter) - Number(actionsBefore)}`);
    console.log(`👑 Captains gained: ${Number(captainsAfter) - Number(captainsBefore)}`);
    console.log(`👥 Crew gained: ${Number(crewAfter) - Number(crewBefore)}`);
    
    if (nftsReceived >= 4) {
      console.log("\n🎉 SUCCESS! Lootbox giving proper amount of NFTs!");
    } else {
      console.log("\n⚠️ WARNING: Lootbox only gave " + nftsReceived + " NFTs (expected ~4-5)");
    }
    
  } catch (error) {
    console.error("❌ Test failed:", error);
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