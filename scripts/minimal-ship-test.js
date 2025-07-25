const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🔬 Minimal Ship Placement Test");
  console.log("==============================");
  
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
    
    // Get NFTs
    const p1ShipId = Number(await shipNFTManager.tokenOfOwnerByIndex(player1.address, 0));
    const p1CaptainId = Number(await captainNFTManager.tokenOfOwnerByIndex(player1.address, 0));
    const p1CrewId = Number(await crewNFTManager.tokenOfOwnerByIndex(player1.address, 0));
    
    console.log(`👤 Player 1: Ship ${p1ShipId}, Captain ${p1CaptainId}, Crew ${p1CrewId}`);
    
    // Check what ship types actually exist by examining the ship NFT
    try {
      const shipInfo = await shipNFTManager.getShipInfo(p1ShipId);
      console.log(`🚢 Ship ${p1ShipId} info:`, shipInfo);
    } catch (e) {
      console.log("⚠️ Could not get ship info");
    }
    
    // ULTRA MINIMAL TEST - All ships in corner, small footprint
    console.log("\n🔬 Testing ultra-minimal placement...");
    
    try {
      // Place all ships as 1-cell ships in safe positions (if possible)
      const shipTypes = [0, 0, 0, 0, 0]; // All same type
      const xPositions = [0, 1, 2, 3, 4]; // Top row, spread horizontally
      const yPositions = [0, 0, 0, 0, 0]; // All on top row
      const rotations = [0, 0, 0, 0, 0]; // All same rotation
      
      console.log("📍 Ultra-safe placement:");
      console.log(`  All type 0 ships in top row: (0,0), (1,0), (2,0), (3,0), (4,0)`);
      console.log(`  All NORTH rotation`);
      
      const placeTx = await battleshipGameP1.placeShips(
        gameId,
        p1ShipId,
        [], // No actions
        p1CaptainId,
        [p1CrewId],
        shipTypes,
        xPositions,
        yPositions,
        rotations,
        { gasLimit: 1200000 }
      );
      
      console.log("⏳ Attempting placement...");
      const receipt = await placeTx.wait();
      console.log("🎉 SUCCESS! Ships placed!");
      
      // Check game status after placement
      const gameInfo = await battleshipGame.getGameInfo(gameId);
      console.log(`📊 Game Status after P1 placement: ${gameInfo.status}`);
      
    } catch (error) {
      console.log(`❌ Even minimal placement failed: ${error.message.split('\n')[0]}`);
      
      // Maybe the issue is that both players need to place ships?
      // Let's check if there's a game state requirement
      console.log("\n🔍 Checking game state requirements...");
      
      try {
        const gameInfo = await battleshipGame.getGameInfo(gameId);
        console.log(`📊 Current game status: ${gameInfo.status}`);
        console.log(`👤 Player 1: ${gameInfo.player1}`);
        console.log(`👤 Player 2: ${gameInfo.player2}`);
        
        // Check if we can see any game state info
        console.log("\n🎯 Checking if game needs both players ready first...");
        
      } catch (stateError) {
        console.log(`❌ Game state check failed: ${stateError.message}`);
      }
    }
    
    console.log("\n💡 Analysis:");
    console.log("- NFT ownership is correct");  
    console.log("- Function exists and is callable");
    console.log("- Issue might be game state, ship validation rules, or grid constraints");
    console.log("- May need to check GameLogic.sol validation functions");
    
  } catch (error) {
    console.error("❌ Test failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Script failed:", error);
    process.exit(1);
  });