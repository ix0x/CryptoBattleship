const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("📦 Player 2 Lootbox Opening");
  console.log("===========================");
  
  // Create Player 2 wallet
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  const player2PrivateKey = "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ef2e2be82b5e09dfc";
  const player2 = new ethers.Wallet(player2PrivateKey, deployer.provider);
  
  console.log(`👤 Player 2: ${player2.address}`);
  
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
    
    // Connect to Player 2
    const battleshipTokenP2 = battleshipToken.connect(player2);
    const lootboxSystemP2 = lootboxSystem.connect(player2);
    
    const lootboxPrice = await lootboxSystem.lootboxPrices(addresses.BattleshipToken);
    console.log(`📦 Lootbox price: ${ethers.formatEther(lootboxPrice)} SHIP`);
    
    // Check balances
    const sonicBalance = await player2.provider.getBalance(player2.address);
    const shipBalance = await battleshipToken.balanceOf(player2.address);
    console.log(`💰 Player 2 balances: ${ethers.formatEther(sonicBalance)} S, ${ethers.formatEther(shipBalance)} SHIP`);
    
    // Get initial NFT counts
    async function getNFTCounts() {
      const ships = await shipNFTManager.balanceOf(player2.address);
      const actions = await actionNFTManager.balanceOf(player2.address);
      const captains = await captainNFTManager.balanceOf(player2.address);
      const crew = await crewNFTManager.balanceOf(player2.address);
      return { ships, actions, captains, crew };
    }
    
    const initialCounts = await getNFTCounts();
    console.log(`📊 Starting NFTs: ${initialCounts.ships} ships, ${initialCounts.actions} actions, ${initialCounts.captains} captains, ${initialCounts.crew} crew`);
    
    // Set allowance
    console.log(`\n💳 Setting allowance...`);
    const totalCost = lootboxPrice * 20n;
    await battleshipTokenP2.approve(addresses.LootboxSystem, totalCost);
    console.log(`✅ Allowance set for ${ethers.formatEther(totalCost)} SHIP`);
    
    // Open lootboxes one by one
    let successfulOpens = 0;
    let totalNFTsGained = 0;
    
    console.log(`\n🎁 Opening 20 lootboxes...`);
    
    for (let i = 1; i <= 20; i++) {
      try {
        // Buy lootbox
        const buyTx = await lootboxSystemP2.buyLootbox(addresses.BattleshipToken, lootboxPrice, {
          gasLimit: 500000 // Set explicit gas limit
        });
        const buyReceipt = await buyTx.wait();
        
        // Get lootbox ID
        let lootboxId = await lootboxSystem.nextLootboxId() - 1n;
        
        // Open lootbox
        const openTx = await lootboxSystemP2.openLootbox(lootboxId, {
          gasLimit: 1000000 // Higher gas limit for opening
        });
        const openReceipt = await openTx.wait();
        
        // Count NFTs from events
        let nftsInThisBox = 0;
        for (const log of openReceipt.logs) {
          try {
            const parsed = lootboxSystem.interface.parseLog(log);
            if (parsed.name === "LootboxOpened") {
              nftsInThisBox = parsed.args[2].length;
              break;
            }
          } catch (e) { /* ignore */ }
        }
        
        successfulOpens++;
        totalNFTsGained += nftsInThisBox;
        console.log(`  ✅ Lootbox ${i}: ${nftsInThisBox} NFTs`);
        
        // Small delay to avoid rate limits
        if (i % 5 === 0) {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
        
      } catch (error) {
        console.log(`  ❌ Lootbox ${i} failed: ${error.message.split('\n')[0]}`);
      }
    }
    
    // Get final counts
    const finalCounts = await getNFTCounts();
    const finalShipBalance = await battleshipToken.balanceOf(player2.address);
    
    console.log(`\n🎉 Player 2 Results:`);
    console.log(`📦 Successful opens: ${successfulOpens}/20`);
    console.log(`📊 Total NFTs gained: ${Number(finalCounts.ships) + Number(finalCounts.actions) + Number(finalCounts.captains) + Number(finalCounts.crew) - Number(initialCounts.ships) - Number(initialCounts.actions) - Number(initialCounts.captains) - Number(initialCounts.crew)}`);
    console.log(`🚢 Ships: ${initialCounts.ships} → ${finalCounts.ships} (+${Number(finalCounts.ships) - Number(initialCounts.ships)})`);
    console.log(`⚔️ Actions: ${initialCounts.actions} → ${finalCounts.actions} (+${Number(finalCounts.actions) - Number(initialCounts.actions)})`);
    console.log(`👑 Captains: ${initialCounts.captains} → ${finalCounts.captains} (+${Number(finalCounts.captains) - Number(initialCounts.captains)})`);
    console.log(`👥 Crew: ${initialCounts.crew} → ${finalCounts.crew} (+${Number(finalCounts.crew) - Number(initialCounts.crew)})`);
    console.log(`💰 SHIP spent: ${ethers.formatEther(shipBalance - finalShipBalance)}`);
    console.log(`💰 SHIP remaining: ${ethers.formatEther(finalShipBalance)}`);
    
    console.log(`\n🎮 Player 2 now has a full collection for testing!`);
    
  } catch (error) {
    console.error("❌ Player 2 lootbox test failed:", error);
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