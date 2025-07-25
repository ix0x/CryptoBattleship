const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("📊 Checking Player 2 Current Status");
  console.log("===================================");
  
  // Player 2 wallet - LOCKED IN
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  const player2PrivateKey = "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ef2e2be82b5e09dfc";
  const player2 = new ethers.Wallet(player2PrivateKey, deployer.provider);
  
  console.log(`👤 Player 2: ${player2.address}`);
  
  // Contract addresses
  const addresses = {
    BattleshipToken: "0x49Dcf31d2e807F2DdC25357EBaE1C40EC29aF6Cd",
    ShipNFTManager: "0x90932BC326bCc7eb61007E373648bE6352E71a90",
    ActionNFTManager: "0xF339ff707Ee7Ced2b4F1823A3C4a069D23AFA56A",
    CaptainNFTManager: "0xFa5b0033df93a2c5c0CDc7374d88Bd4a824032f2",
    CrewNFTManager: "0x17e9BDFD27FFd16Bf7543180534dF28f8F64d998"
  };
  
  try {
    // Get contract instances
    const battleshipToken = await ethers.getContractAt("BattleshipToken", addresses.BattleshipToken);
    const shipNFTManager = await ethers.getContractAt("ShipNFTManager", addresses.ShipNFTManager);
    const actionNFTManager = await ethers.getContractAt("ActionNFTManager", addresses.ActionNFTManager);
    const captainNFTManager = await ethers.getContractAt("CaptainNFTManager", addresses.CaptainNFTManager);
    const crewNFTManager = await ethers.getContractAt("CrewNFTManager", addresses.CrewNFTManager);
    
    // Check balances
    const sonicBalance = await player2.provider.getBalance(player2.address);
    const shipBalance = await battleshipToken.balanceOf(player2.address);
    
    console.log(`💰 Current Balances:`);
    console.log(`⛽ Sonic: ${ethers.formatEther(sonicBalance)} S`);
    console.log(`🚢 SHIP: ${ethers.formatEther(shipBalance)} SHIP`);
    
    // Get NFT counts
    const ships = await shipNFTManager.balanceOf(player2.address);
    const actions = await actionNFTManager.balanceOf(player2.address);
    const captains = await captainNFTManager.balanceOf(player2.address);
    const crew = await crewNFTManager.balanceOf(player2.address);
    const totalNFTs = Number(ships) + Number(actions) + Number(captains) + Number(crew);
    
    console.log(`\n🎯 Current NFT Collection:`);
    console.log(`🚢 Ships: ${ships}`);
    console.log(`⚔️ Actions: ${actions}`);
    console.log(`👑 Captains: ${captains}`);
    console.log(`👥 Crew: ${crew}`);
    console.log(`📊 Total NFTs: ${totalNFTs}`);
    
    // Check gameplay readiness
    const hasShips = Number(ships) > 0;
    const hasCaptains = Number(captains) > 0;
    const hasActions = Number(actions) > 0;
    const hasCrew = Number(crew) > 0;
    
    console.log(`\n🎮 GAMEPLAY READINESS:`);
    console.log(`🚢 Has Ships: ${hasShips ? '✅' : '❌'} (need 1+)`);
    console.log(`👑 Has Captains: ${hasCaptains ? '✅' : '❌'} (need 1+)`);
    console.log(`⚔️ Has Actions: ${hasActions ? '✅' : '❌'} (recommended)`);
    console.log(`👥 Has Crew: ${hasCrew ? '✅' : '❌'} (recommended)`);
    
    if (hasShips && hasCaptains) {
      console.log(`\n🎉 Player 2 is READY for gameplay!`);
      console.log(`✅ Can create and join games`);
      console.log(`✅ Has ${ships} ships and ${captains} captains`);
    } else {
      console.log(`\n⚠️ Player 2 needs more lootboxes`);
      console.log(`❌ Missing: ${hasShips ? '' : 'ships '}${hasCaptains ? '' : 'captains'}`);
      
      const lootboxPrice = ethers.parseEther("10");
      const canAfford = Math.floor(Number(shipBalance) / Number(lootboxPrice));
      console.log(`💡 Can afford ${canAfford} more lootboxes`);
    }
    
    // Compare with Player 1
    console.log(`\n👥 Player Comparison:`);
    const p1Ships = await shipNFTManager.balanceOf("0xb96Fa45d47a1C60cD76A555A4C3Ed3af6eEb1096");
    const p1Actions = await actionNFTManager.balanceOf("0xb96Fa45d47a1C60cD76A555A4C3Ed3af6eEb1096");
    const p1Captains = await captainNFTManager.balanceOf("0xb96Fa45d47a1C60cD76A555A4C3Ed3af6eEb1096");
    const p1Crew = await crewNFTManager.balanceOf("0xb96Fa45d47a1C60cD76A555A4C3Ed3af6eEb1096");
    const p1Total = Number(p1Ships) + Number(p1Actions) + Number(p1Captains) + Number(p1Crew);
    
    console.log(`👤 Player 1: ${p1Total} total (🚢${p1Ships} ⚔️${p1Actions} 👑${p1Captains} 👥${p1Crew})`);
    console.log(`👤 Player 2: ${totalNFTs} total (🚢${ships} ⚔️${actions} 👑${captains} 👥${crew})`);
    
    if (totalNFTs < 20) {
      console.log(`\n💡 Recommendation: Open ${Math.min(10, canAfford)} more lootboxes for Player 2`);
    } else {
      console.log(`\n🎊 Both players have good collections for testing!`);
    }
    
  } catch (error) {
    console.error("❌ Status check failed:", error);
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