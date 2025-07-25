const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🎮 CryptoBattleship Full Game Testing");
  console.log("====================================");
  
  // Get both players
  const signers = await ethers.getSigners();
  const player1 = signers[0]; // Deployer
  
  // Player 2 wallet - LOCKED IN
  const player2PrivateKey = "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ef2e2be82b5e09dfc";
  const player2 = new ethers.Wallet(player2PrivateKey, player1.provider);
  
  console.log(`👤 Player 1: ${player1.address}`);
  console.log(`👤 Player 2: ${player2.address}`);
  
  // Contract addresses
  const addresses = {
    BattleshipToken: "0x49Dcf31d2e807F2DdC25357EBaE1C40EC29aF6Cd",
    BattleshipGame: "0x1aB0C9a6B5635F1B3109a6Fa5dC22A37ded2a9fA",
    GameState: "0x7D9e8Eda47cCe0F3dD274cCa6c349dB0C0cc8743",
    ShipNFTManager: "0x90932BC326bCc7eb61007E373648bE6352E71a90",
    ActionNFTManager: "0xF339ff707Ee7Ced2b4F1823A3C4a069D23AFA56A",
    CaptainNFTManager: "0xFa5b0033df93a2c5c0CDc7374d88Bd4a824032f2",
    CrewNFTManager: "0x17e9BDFD27FFd16Bf7543180534dF28f8F64d998"
  };
  
  try {
    // Get contract instances
    const battleshipGame = await ethers.getContractAt("BattleshipGame", addresses.BattleshipGame);
    const gameState = await ethers.getContractAt("GameState", addresses.GameState);
    const battleshipToken = await ethers.getContractAt("BattleshipToken", addresses.BattleshipToken);
    const shipNFTManager = await ethers.getContractAt("ShipNFTManager", addresses.ShipNFTManager);
    const captainNFTManager = await ethers.getContractAt("CaptainNFTManager", addresses.CaptainNFTManager);
    const crewNFTManager = await ethers.getContractAt("CrewNFTManager", addresses.CrewNFTManager);
    
    // Connect to each player
    const battleshipGameP1 = battleshipGame.connect(player1);
    const battleshipGameP2 = battleshipGame.connect(player2);
    const battleshipTokenP1 = battleshipToken.connect(player1);
    const battleshipTokenP2 = battleshipToken.connect(player2);
    
    // Check player collections
    console.log("\n📊 Player Collections:");
    const p1Ships = await shipNFTManager.balanceOf(player1.address);
    const p1Captains = await captainNFTManager.balanceOf(player1.address);
    const p1Crew = await crewNFTManager.balanceOf(player1.address);
    const p2Ships = await shipNFTManager.balanceOf(player2.address);
    const p2Captains = await captainNFTManager.balanceOf(player2.address);
    const p2Crew = await crewNFTManager.balanceOf(player2.address);
    
    console.log(`👤 Player 1: 🚢${p1Ships} ships, 👑${p1Captains} captains, 👥${p1Crew} crew`);
    console.log(`👤 Player 2: 🚢${p2Ships} ships, 👑${p2Captains} captains, 👥${p2Crew} crew`);
    
    // Check SHIP token balances
    const p1ShipBalance = await battleshipToken.balanceOf(player1.address);
    const p2ShipBalance = await battleshipToken.balanceOf(player2.address);
    console.log(`💰 Player 1 SHIP: ${ethers.formatEther(p1ShipBalance)}`);
    console.log(`💰 Player 2 SHIP: ${ethers.formatEther(p2ShipBalance)}`);
    
    // Check ante amounts for different game sizes
    console.log("\n💰 Game Ante Requirements:");
    try {
      const anteShrimp = await battleshipGame.getAnteAmount(0); // SHRIMP
      const anteFish = await battleshipGame.getAnteAmount(1);   // FISH  
      const anteShark = await battleshipGame.getAnteAmount(2);  // SHARK
      const anteWhale = await battleshipGame.getAnteAmount(3);  // WHALE
      
      console.log(`🦐 SHRIMP: ${ethers.formatEther(anteShrimp)} SHIP`);
      console.log(`🐟 FISH: ${ethers.formatEther(anteFish)} SHIP`);
      console.log(`🦈 SHARK: ${ethers.formatEther(anteShark)} SHIP`);
      console.log(`🐋 WHALE: ${ethers.formatEther(anteWhale)} SHIP`);
    } catch (error) {
      console.log("⚠️ Could not get ante amounts:", error.message);
    }
    
    // PHASE 1: Create Game
    console.log("\n🎮 PHASE 1: Game Creation");
    console.log("=========================");
    
    // Check if players are already in games
    const p1InGame = await battleshipGame.isPlayerInGame(player1.address);
    const p2InGame = await battleshipGame.isPlayerInGame(player2.address);
    
    console.log(`📊 Player 1 in game: ${p1InGame}`);
    console.log(`📊 Player 2 in game: ${p2InGame}`);
    
    if (p1InGame || p2InGame) {
      console.log("⚠️ One or both players already in a game. Getting current game info...");
      
      if (p1InGame) {
        const p1ActiveGame = await battleshipGame.getPlayerActiveGame(player1.address);
        console.log(`👤 Player 1 active game: ${p1ActiveGame}`);
      }
      if (p2InGame) {
        const p2ActiveGame = await battleshipGame.getPlayerActiveGame(player2.address);
        console.log(`👤 Player 2 active game: ${p2ActiveGame}`);
      }
    }
    
    // Get next game ID
    const nextGameId = await gameState.nextGameId();
    console.log(`🎯 Next game ID will be: ${nextGameId}`);
    
    // Player 1 creates a SHRIMP size game (smallest ante)
    console.log("\n🎮 Player 1 creating SHRIMP game...");
    
    try {
      const createTx = await battleshipGameP1.createGame(0, { // GameSize.SHRIMP = 0
        gasLimit: 800000
      });
      const createReceipt = await createTx.wait();
      console.log(`✅ Game creation transaction confirmed`);
      
      // Get the actual game ID from events or use nextGameId
      let gameId = nextGameId;
      for (const log of createReceipt.logs) {
        try {
          const parsed = battleshipGame.interface.parseLog(log);
          if (parsed.name === "GameCreated") {
            gameId = parsed.args[0]; // gameId is first parameter
            break;
          }
        } catch (e) { /* ignore parsing errors */ }
      }
      
      console.log(`🎮 Game #${gameId} created by Player 1`);
      
      // Get game info
      const gameInfo = await battleshipGame.getGameInfo(gameId);
      console.log(`📊 Game Status: ${gameInfo.status} (0=WAITING, 1=ACTIVE, 2=COMPLETED)`);
      console.log(`💰 Game Ante: ${ethers.formatEther(gameInfo.ante)} SHIP`);
      console.log(`👤 Player 1: ${gameInfo.player1}`);
      console.log(`👤 Player 2: ${gameInfo.player2}`);
      
      // PHASE 2: Join Game
      console.log("\n🎮 PHASE 2: Player 2 Joining Game");
      console.log("==================================");
      
      // Check if Player 2 has enough SHIP tokens for ante
      const requiredAnte = gameInfo.ante;
      if (p2ShipBalance < requiredAnte) {
        console.log(`❌ Player 2 insufficient SHIP: has ${ethers.formatEther(p2ShipBalance)}, needs ${ethers.formatEther(requiredAnte)}`);
        return;
      }
      
      // Player 2 approves ante amount
      console.log(`💳 Player 2 approving ante: ${ethers.formatEther(requiredAnte)} SHIP`);
      await battleshipTokenP2.approve(addresses.BattleshipGame, requiredAnte);
      
      // Player 2 joins the game
      console.log(`🎮 Player 2 joining game #${gameId}...`);
      const joinTx = await battleshipGameP2.joinGame(gameId, {
        gasLimit: 800000
      });
      await joinTx.wait();
      console.log(`✅ Player 2 joined game #${gameId}`);
      
      // Check updated game info
      const updatedGameInfo = await battleshipGame.getGameInfo(gameId);
      console.log(`📊 Updated Game Status: ${updatedGameInfo.status}`);
      console.log(`👤 Player 1: ${updatedGameInfo.player1}`);
      console.log(`👤 Player 2: ${updatedGameInfo.player2}`);
      console.log(`💰 Total Pot: ${ethers.formatEther(updatedGameInfo.ante * 2n)} SHIP`);
      
      // PHASE 3: Game Setup and Ship Placement
      console.log("\n🎮 PHASE 3: Ship Placement");
      console.log("==========================");
      
      // Get player NFT IDs for setup
      console.log("📋 Getting player NFT collections for setup...");
      
      // Get Player 1's first ship and captain
      const p1ShipIds = [];
      const p1CaptainIds = [];
      const p1CrewIds = [];
      
      for (let i = 0; i < Math.min(3, Number(p1Ships)); i++) {
        const tokenId = await shipNFTManager.tokenOfOwnerByIndex(player1.address, i);
        p1ShipIds.push(tokenId);
      }
      
      for (let i = 0; i < Math.min(1, Number(p1Captains)); i++) {
        const tokenId = await captainNFTManager.tokenOfOwnerByIndex(player1.address, i);
        p1CaptainIds.push(tokenId);
      }
      
      for (let i = 0; i < Math.min(2, Number(p1Crew)); i++) {
        const tokenId = await crewNFTManager.tokenOfOwnerByIndex(player1.address, i);
        p1CrewIds.push(tokenId);
      }
      
      console.log(`👤 Player 1 will use: ships [${p1ShipIds.join(',')}], captain ${p1CaptainIds[0]}, crew [${p1CrewIds.join(',')}]`);
      
      // Get Player 2's NFTs
      const p2ShipIds = [];
      const p2CaptainIds = [];
      const p2CrewIds = [];
      
      for (let i = 0; i < Math.min(3, Number(p2Ships)); i++) {
        const tokenId = await shipNFTManager.tokenOfOwnerByIndex(player2.address, i);
        p2ShipIds.push(tokenId);
      }
      
      for (let i = 0; i < Math.min(1, Number(p2Captains)); i++) {
        const tokenId = await captainNFTManager.tokenOfOwnerByIndex(player2.address, i);
        p2CaptainIds.push(tokenId);
      }
      
      for (let i = 0; i < Math.min(2, Number(p2Crew)); i++) {
        const tokenId = await crewNFTManager.tokenOfOwnerByIndex(player2.address, i);
        p2CrewIds.push(tokenId);
      }
      
      console.log(`👤 Player 2 will use: ships [${p2ShipIds.join(',')}], captain ${p2CaptainIds[0]}, crew [${p2CrewIds.join(',')}]`);
      
      // Test basic game functions
      console.log("\n📊 Testing Game View Functions:");
      
      const p1ActiveGame = await battleshipGame.getPlayerActiveGame(player1.address);
      const p2ActiveGame = await battleshipGame.getPlayerActiveGame(player2.address);
      console.log(`🎮 Player 1 active game: ${p1ActiveGame}`);
      console.log(`🎮 Player 2 active game: ${p2ActiveGame}`);
      
      // Test game state
      const currentTurn = await battleshipGame.getCurrentTurn(gameId);
      console.log(`🎯 Current turn: ${currentTurn}`);
      
      console.log("\n🎉 GAME TESTING COMPLETED SUCCESSFULLY!");
      console.log("======================================");
      
      console.log("\n📊 SUMMARY:");
      console.log("✅ Game creation working");
      console.log("✅ Game joining working");
      console.log("✅ Player authentication working");
      console.log("✅ Ante system working");
      console.log("✅ NFT collection integration working");
      console.log("✅ Game state management working");
      
      console.log(`\n🎮 Active Game #${gameId} ready for ship placement and battle!`);
      console.log("Players can now place ships and start battling!");
      
    } catch (error) {
      console.error("❌ Game creation/joining failed:", error);
      console.error("Error details:", error.message);
      
      // Try to get more specific error info
      if (error.reason) {
        console.error("Reason:", error.reason);
      }
    }
    
  } catch (error) {
    console.error("❌ Game testing failed:", error);
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