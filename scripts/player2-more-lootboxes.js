const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("📦 Player 2 - Opening More Lootboxes");
  console.log("====================================");
  
  // Player 2 wallet - LOCKED IN
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
    
    const maxLootboxes = Math.floor(Number(shipBalance) / Number(lootboxPrice));
    console.log(`📊 Can afford ${maxLootboxes} lootboxes`);
    
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
    
    // Set high allowance to avoid repeated approvals
    console.log(`\n💳 Setting allowance for remaining SHIP...`);
    await battleshipTokenP2.approve(addresses.LootboxSystem, shipBalance);
    console.log(`✅ Allowance set for ${ethers.formatEther(shipBalance)} SHIP`);
    
    // Try to open lootboxes more carefully with longer delays
    let successfulOpens = 0;
    const targetLootboxes = Math.min(30, maxLootboxes); // Try up to 30 lootboxes
    
    console.log(`\n🎁 Attempting to open ${targetLootboxes} lootboxes...`);
    console.log("Using slower pace with longer delays to avoid revert issues");
    
    for (let i = 1; i <= targetLootboxes; i++) {
      try {
        console.log(`\n📦 Lootbox ${i}/${targetLootboxes}:`);
        
        // Buy lootbox with conservative gas settings
        console.log(`  💰 Buying...`);
        const buyTx = await lootboxSystemP2.buyLootbox(addresses.BattleshipToken, lootboxPrice, {
          gasLimit: 800000, // Higher gas limit
          gasPrice: ethers.parseUnits("25", "gwei") // Higher gas price for reliability
        });
        const buyReceipt = await buyTx.wait();
        
        // Get lootbox ID
        let lootboxId = await lootboxSystem.nextLootboxId() - 1n;
        console.log(`  📦 Got lootbox #${lootboxId}`);
        
        // Wait a bit before opening to avoid issues
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Open lootbox
        console.log(`  🎁 Opening...`);
        const openTx = await lootboxSystemP2.openLootbox(lootboxId, {
          gasLimit: 1500000, // Very high gas limit for opening
          gasPrice: ethers.parseUnits("25", "gwei")
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
        console.log(`  ✅ SUCCESS! Received ${nftsInThisBox} NFTs`);
        
        // Longer delay between lootboxes to avoid network issues
        if (i < targetLootboxes) {
          console.log(`  ⏳ Waiting 8 seconds before next lootbox...`);
          await new Promise(resolve => setTimeout(resolve, 8000));
        }
        
      } catch (error) {
        console.log(`  ❌ FAILED: ${error.message.split('\n')[0]}`);
        // Wait even longer after failures
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
      
      // Show progress every 5 lootboxes
      if (i % 5 === 0) {
        const currentCounts = await getNFTCounts();
        const currentTotal = Number(currentCounts.ships) + Number(currentCounts.actions) + Number(currentCounts.captains) + Number(currentCounts.crew);
        console.log(`\n📊 Progress update: ${successfulOpens}/${i} successful, ${currentTotal} total NFTs`);
      }
    }
    
    // Get final counts
    const finalCounts = await getNFTCounts();
    const finalShipBalance = await battleshipToken.balanceOf(player2.address);
    
    const shipsGained = Number(finalCounts.ships) - Number(initialCounts.ships);
    const actionsGained = Number(finalCounts.actions) - Number(initialCounts.actions);
    const captainsGained = Number(finalCounts.captains) - Number(initialCounts.captains);
    const crewGained = Number(finalCounts.crew) - Number(initialCounts.crew);
    const totalGained = shipsGained + actionsGained + captainsGained + crewGained;
    
    console.log(`\n🎉 FINAL RESULTS FOR PLAYER 2:`);
    console.log(`===============================`);
    console.log(`📦 Successful opens: ${successfulOpens}/${targetLootboxes}`);
    console.log(`📊 Total NFTs gained: ${totalGained}`);
    console.log(`🚢 Ships: ${initialCounts.ships} → ${finalCounts.ships} (+${shipsGained})`);
    console.log(`⚔️ Actions: ${initialCounts.actions} → ${finalCounts.actions} (+${actionsGained})`);
    console.log(`👑 Captains: ${initialCounts.captains} → ${finalCounts.captains} (+${captainsGained})`);
    console.log(`👥 Crew: ${initialCounts.crew} → ${finalCounts.crew} (+${crewGained})`);
    console.log(`💰 SHIP spent: ${ethers.formatEther(shipBalance - finalShipBalance)}`);
    console.log(`💰 SHIP remaining: ${ethers.formatEther(finalShipBalance)}`);
    
    // Check if ready for gameplay
    const hasShips = Number(finalCounts.ships) > 0;
    const hasCaptains = Number(finalCounts.captains) > 0;
    const hasActions = Number(finalCounts.actions) > 0;
    const hasCrew = Number(finalCounts.crew) > 0;
    
    console.log(`\n🎮 GAMEPLAY READINESS:`);
    console.log(`🚢 Has Ships: ${hasShips ? '✅' : '❌'} (${finalCounts.ships})`);
    console.log(`👑 Has Captains: ${hasCaptains ? '✅' : '❌'} (${finalCounts.captains})`);
    console.log(`⚔️ Has Actions: ${hasActions ? '✅' : '❌'} (${finalCounts.actions})`);
    console.log(`👥 Has Crew: ${hasCrew ? '✅' : '❌'} (${finalCounts.crew})`);
    
    if (hasShips && hasCaptains) {
      console.log(`\n🎉 Player 2 is ready for gameplay! Can create and join games!`);
    } else {
      console.log(`\n⚠️ Player 2 needs ${hasShips ? '' : 'ships '}${hasCaptains ? '' : 'captains '} to play`);
    }
    
  } catch (error) {
    console.error("❌ Lootbox opening failed:", error);
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