const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🔍 Debug Ship Placement");
  console.log("=======================");
  
  // Get both players
  const signers = await ethers.getSigners();
  const player1 = signers[0];
  
  const gameId = 1;
  
  try {
    // Get contract instances
    const battleshipGame = await ethers.getContractAt("BattleshipGame", "0x1aB0C9a6B5635F1B3109a6Fa5dC22A37ded2a9fA");
    const shipNFTManager = await ethers.getContractAt("ShipNFTManager", "0x90932BC326bCc7eb61007E373648bE6352E71a90");
    const captainNFTManager = await ethers.getContractAt("CaptainNFTManager", "0xFa5b0033df93a2c5c0CDc7374d88Bd4a824032f2");
    const crewNFTManager = await ethers.getContractAt("CrewNFTManager", "0x17e9BDFD27FFd16Bf7543180534dF28f8F64d998");
    
    const battleshipGameP1 = battleshipGame.connect(player1);
    
    // Get Player 1's NFTs
    const p1ShipId = Number(await shipNFTManager.tokenOfOwnerByIndex(player1.address, 0));
    const p1CaptainId = Number(await captainNFTManager.tokenOfOwnerByIndex(player1.address, 0));
    const p1CrewId = Number(await crewNFTManager.tokenOfOwnerByIndex(player1.address, 0));
    
    console.log(`👤 Player 1: Ship ${p1ShipId}, Captain ${p1CaptainId}, Crew ${p1CrewId}`);
    
    // Check game status
    const gameInfo = await battleshipGame.getGameInfo(gameId);
    console.log(`📊 Game Status: ${gameInfo.status}`);
    console.log(`👤 Players: ${gameInfo.player1} vs ${gameInfo.player2}`);
    
    // Simple ship placement test - with proper spacing
    console.log("\n🚢 Testing ship placement with proper bounds...");
    
    try {
      // Use GameState.ShipRotation enum: NORTH=0, EAST=1, SOUTH=2, WEST=3
      // Assume ship lengths: Type 0=2 cells, Type 1=3 cells, Type 2=4 cells
      // Grid is 10x10 (0-9), so for vertical ships starting at Y, max Y = 9 - (shipLength - 1)
      
      const shipTypes = [0, 1, 2, 0, 1]; // Ship types (2, 3, 4, 2, 3 cell lengths)
      const xPositions = [1, 3, 5, 7, 0]; // X positions spread out
      const yPositions = [0, 0, 0, 3, 6]; // Y positions: 0+2≤9, 0+3≤9, 0+4≤9, 3+2≤9, 6+3≤9
      const rotations = [0, 0, 0, 1, 1]; // Mix: vertical, vertical, vertical, horizontal, horizontal
      
      console.log("📍 Placement data:");
      console.log(`  Ship ID: ${p1ShipId}`);
      console.log(`  Action IDs: [] (empty)`);
      console.log(`  Captain ID: ${p1CaptainId}`);
      console.log(`  Crew IDs: [${p1CrewId}]`);
      console.log(`  Ship Types: [${shipTypes.join(',')}]`);
      console.log(`  X Positions: [${xPositions.join(',')}]`);
      console.log(`  Y Positions: [${yPositions.join(',')}]`);
      console.log(`  Rotations: [${rotations.join(',')}] (0=NORTH/vertical, 1=EAST/horizontal)`);
      
      const placeTx = await battleshipGameP1.placeShips(
        gameId,
        p1ShipId,
        [], // No action NFTs
        p1CaptainId,
        [p1CrewId], // Single crew member
        shipTypes,
        xPositions,
        yPositions,
        rotations,
        { gasLimit: 1000000 }
      );
      
      console.log("⏳ Transaction sent, waiting...");
      const receipt = await placeTx.wait();
      console.log("✅ Ship placement successful!");
      console.log(`📝 Transaction hash: ${receipt.hash}`);
      
    } catch (error) {
      console.log(`❌ Ship placement failed: ${error.message}`);
      
      // Try to get more details about the error
      if (error.reason) {
        console.log(`📄 Reason: ${error.reason}`);
      }
      
      if (error.data) {
        console.log(`📊 Error data: ${error.data}`);
      }
      
      // Check NFT ownerships
      console.log("\n🔍 Checking NFT ownerships:");
      const shipOwner = await shipNFTManager.ownerOf(p1ShipId);
      const captainOwner = await captainNFTManager.ownerOf(p1CaptainId);
      const crewOwner = await crewNFTManager.ownerOf(p1CrewId);
      
      console.log(`🚢 Ship ${p1ShipId} owner: ${shipOwner}`);
      console.log(`👑 Captain ${p1CaptainId} owner: ${captainOwner}`);
      console.log(`👥 Crew ${p1CrewId} owner: ${crewOwner}`);
      console.log(`👤 Player address: ${player1.address}`);
      
      const shipOwned = shipOwner.toLowerCase() === player1.address.toLowerCase();
      const captainOwned = captainOwner.toLowerCase() === player1.address.toLowerCase();
      const crewOwned = crewOwner.toLowerCase() === player1.address.toLowerCase();
      
      console.log(`✅ Ownerships: Ship ${shipOwned}, Captain ${captainOwned}, Crew ${crewOwned}`);
    }
    
  } catch (error) {
    console.error("❌ Debug failed:", error);
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