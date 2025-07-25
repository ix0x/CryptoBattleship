const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("📦 Bulk Lootbox Opening - Building Test Collections");
  console.log("=================================================");
  
  // Get signers - use deployer and second test wallet
  const signers = await ethers.getSigners();
  const player1 = signers[0]; // Main deployer wallet
  
  // Create second wallet from private key
  const player2PrivateKey = "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ef2e2be82b5e09dfc";
  const player2 = new ethers.Wallet(player2PrivateKey, player1.provider);
  
  console.log(`👤 Player 1: ${player1.address}`);
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
    
    const lootboxPrice = await lootboxSystem.lootboxPrices(addresses.BattleshipToken);
    console.log(`📦 Lootbox price: ${ethers.formatEther(lootboxPrice)} SHIP`);
    
    // Check initial balances
    const p1Balance = await battleshipToken.balanceOf(player1.address);
    const p2Balance = await battleshipToken.balanceOf(player2.address);
    console.log(`💰 Player 1 SHIP Balance: ${ethers.formatEther(p1Balance)}`);
    console.log(`💰 Player 2 SHIP Balance: ${ethers.formatEther(p2Balance)}`);
    
    // Function to get NFT counts for a player
    async function getNFTCounts(playerAddress) {
      const ships = await shipNFTManager.balanceOf(playerAddress);
      const actions = await actionNFTManager.balanceOf(playerAddress);
      const captains = await captainNFTManager.balanceOf(playerAddress);
      const crew = await crewNFTManager.balanceOf(playerAddress);
      return { ships, actions, captains, crew };
    }
    
    // Function to open lootboxes for a player
    async function openLootboxesForPlayer(player, playerName, count) {
      console.log(`\n🎁 Opening ${count} lootboxes for ${playerName}...`);
      console.log("=".repeat(50));
      
      const battleshipTokenPlayer = battleshipToken.connect(player);
      const lootboxSystemPlayer = lootboxSystem.connect(player);
      
      // Get initial NFT counts
      const initialCounts = await getNFTCounts(player.address);
      console.log(`📊 ${playerName} starting NFTs: ${initialCounts.ships} ships, ${initialCounts.actions} actions, ${initialCounts.captains} captains, ${initialCounts.crew} crew`);
      
      // Check balance and approve if needed
      const balance = await battleshipToken.balanceOf(player.address);
      const totalCost = lootboxPrice * BigInt(count);
      
      if (balance < totalCost) {
        console.log(`❌ ${playerName} insufficient balance: ${ethers.formatEther(balance)} SHIP (needs ${ethers.formatEther(totalCost)})`);
        return;
      }
      
      // Set high allowance
      console.log(`💳 Setting allowance for ${playerName}...`);
      await battleshipTokenPlayer.approve(addresses.LootboxSystem, totalCost * 2n);
      
      let totalNFTsGained = 0;
      let shipCount = 0, actionCount = 0, captainCount = 0, crewCount = 0;
      
      // Open lootboxes in batches of 5 to avoid gas issues
      for (let batch = 0; batch < Math.ceil(count / 5); batch++) {
        const batchStart = batch * 5;
        const batchEnd = Math.min(batchStart + 5, count);
        const batchSize = batchEnd - batchStart;
        
        console.log(`\n📦 ${playerName} Batch ${batch + 1}: Opening lootboxes ${batchStart + 1}-${batchEnd}...`);
        
        for (let i = 0; i < batchSize; i++) {
          const lootboxNum = batchStart + i + 1;
          
          try {
            // Buy lootbox
            const buyTx = await lootboxSystemPlayer.buyLootbox(addresses.BattleshipToken, lootboxPrice);
            const buyReceipt = await buyTx.wait();
            
            // Get lootbox ID
            let lootboxId = await lootboxSystem.nextLootboxId() - 1n;
            for (const log of buyReceipt.logs) {
              try {
                const parsed = lootboxSystem.interface.parseLog(log);
                if (parsed.name === "LootboxPurchased") {
                  lootboxId = parsed.args[1];
                  break;
                }
              } catch (e) { /* ignore */ }
            }
            
            // Open lootbox
            const openTx = await lootboxSystemPlayer.openLootbox(lootboxId);
            const openReceipt = await openTx.wait();
            
            // Parse the opened NFTs from events
            let lootboxNFTs = 0;
            for (const log of openReceipt.logs) {
              try {
                const parsed = lootboxSystem.interface.parseLog(log);
                if (parsed.name === "LootboxOpened") {
                  lootboxNFTs = parsed.args[2].length; // nftIds array length
                  break;
                }
              } catch (e) { /* ignore */ }
            }
            
            totalNFTsGained += lootboxNFTs;
            console.log(`  ✅ Lootbox ${lootboxNum}: ${lootboxNFTs} NFTs`);
            
          } catch (error) {
            console.log(`  ❌ Lootbox ${lootboxNum} failed: ${error.message}`);
          }
        }
        
        // Small delay between batches
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
      
      // Get final NFT counts
      const finalCounts = await getNFTCounts(player.address);
      
      shipCount = Number(finalCounts.ships) - Number(initialCounts.ships);
      actionCount = Number(finalCounts.actions) - Number(initialCounts.actions);
      captainCount = Number(finalCounts.captains) - Number(initialCounts.captains);
      crewCount = Number(finalCounts.crew) - Number(initialCounts.crew);
      
      console.log(`\n🎉 ${playerName} Results:`);
      console.log(`📊 Total NFTs gained: ${shipCount + actionCount + captainCount + crewCount}`);
      console.log(`🚢 Ships: ${initialCounts.ships} → ${finalCounts.ships} (+${shipCount})`);
      console.log(`⚔️ Actions: ${initialCounts.actions} → ${finalCounts.actions} (+${actionCount})`);
      console.log(`👑 Captains: ${initialCounts.captains} → ${finalCounts.captains} (+${captainCount})`);
      console.log(`👥 Crew: ${initialCounts.crew} → ${finalCounts.crew} (+${crewCount})`);
      
      const finalBalance = await battleshipToken.balanceOf(player.address);
      console.log(`💰 SHIP spent: ${ethers.formatEther(balance - finalBalance)}`);
      console.log(`💰 SHIP remaining: ${ethers.formatEther(finalBalance)}`);
    }
    
    // Transfer some SHIP to player 2 if needed
    if (p2Balance < lootboxPrice * 20n) {
      console.log(`\n💸 Transferring SHIP to Player 2...`);
      const transferAmount = lootboxPrice * 25n; // 25 lootboxes worth
      await battleshipToken.transfer(player2.address, transferAmount);
      const newP2Balance = await battleshipToken.balanceOf(player2.address);
      console.log(`✅ Player 2 new balance: ${ethers.formatEther(newP2Balance)} SHIP`);
    }
    
    // Open lootboxes for both players
    await openLootboxesForPlayer(player1, "Player 1", 20);
    await openLootboxesForPlayer(player2, "Player 2", 20);
    
    console.log("\n🎊 BULK LOOTBOX OPENING COMPLETE!");
    console.log("===================================");
    
    // Final summary
    const p1FinalCounts = await getNFTCounts(player1.address);
    const p2FinalCounts = await getNFTCounts(player2.address);
    
    console.log("\n📊 FINAL COLLECTIONS:");
    console.log(`👤 Player 1 (${player1.address}):`);
    console.log(`   🚢 Ships: ${p1FinalCounts.ships}, ⚔️ Actions: ${p1FinalCounts.actions}, 👑 Captains: ${p1FinalCounts.captains}, 👥 Crew: ${p1FinalCounts.crew}`);
    console.log(`👤 Player 2 (${player2.address}):`);
    console.log(`   🚢 Ships: ${p2FinalCounts.ships}, ⚔️ Actions: ${p2FinalCounts.actions}, 👑 Captains: ${p2FinalCounts.captains}, 👥 Crew: ${p2FinalCounts.crew}`);
    
    console.log("\n🎮 Both players now have comprehensive NFT collections for testing!");
    console.log("Ready for full gameplay testing with ships, captains, crew, and actions!");
    
  } catch (error) {
    console.error("❌ Bulk test failed:", error);
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