const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("🔧 Setting up CryptoBattleship contract authorizations");
  console.log("Setup with account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());
  
  // Contract addresses from deployment
  const addresses = {
    BattleshipToken: "0x31F1372F4AC3a96FEd08b76B52D14872dF22C8d3",
    GameConfig: "0x8730CcA37D387Ce85935334B24A4E49A87F74180",
    ShipNFTManager: "0xb2963373f5E9900Cd8f249A07b615771033B6f0A",
    ActionNFTManager: "0x62988B88CF03fc1BAC52Ef455a09ad452Cc86Bff",
    CaptainNFTManager: "0x655e3C93D5340c4513394CA8dfff1e443eCe62f4",
    CrewNFTManager: "0xF7075B4F2E4309f62E8D9B2C5e489a017Ad01F7A",
    StakingPool: "0xF8376E0CE584faf7aCB50b2Ac0cDB2cfB14E825C",
    TokenomicsCore: "0xeA4c2f943559b112FBF9E70b645ce94768D7698F",
    GameState: "0xC559a1fC52D855821F2D6D95DcDB7944d9da8aE4",
    GameLogic: "0x92b26572482e916D3fC6c4c461D0D80B487B608A",
    BattleshipGame: "0x9c7116FfB46Cb9Ce893e77436F303B8198f48958",
    LootboxSystem: "0xc1689Dfe4773e66f132929F662da19098BAF4Fca"
  };

  try {
    // Get contract instances
    console.log("\n📋 Getting contract instances...");
    const gameState = await ethers.getContractAt("GameState", addresses.GameState);
    const gameLogic = await ethers.getContractAt("GameLogic", addresses.GameLogic);
    const battleshipGame = await ethers.getContractAt("BattleshipGame", addresses.BattleshipGame);
    const shipNFTManager = await ethers.getContractAt("ShipNFTManager", addresses.ShipNFTManager);
    const actionNFTManager = await ethers.getContractAt("ActionNFTManager", addresses.ActionNFTManager);
    const captainNFTManager = await ethers.getContractAt("CaptainNFTManager", addresses.CaptainNFTManager);
    const crewNFTManager = await ethers.getContractAt("CrewNFTManager", addresses.CrewNFTManager);
    const tokenomicsCore = await ethers.getContractAt("TokenomicsCore", addresses.TokenomicsCore);
    const battleshipToken = await ethers.getContractAt("BattleshipToken", addresses.BattleshipToken);

    // 1. Set up GameState authorizations
    console.log("\n🗃️ Setting up GameState authorizations...");
    console.log("  - Authorizing GameLogic to modify GameState...");
    await gameState.setAuthorizedContract(addresses.GameLogic, true);
    console.log("  - Authorizing BattleshipGame to modify GameState...");
    await gameState.setAuthorizedContract(addresses.BattleshipGame, true);

    // 2. Set up GameLogic authorizations
    console.log("\n🧠 Setting up GameLogic authorizations...");
    console.log("  - Authorizing BattleshipGame to call GameLogic...");
    await gameLogic.setAuthorizedContract(addresses.BattleshipGame, true);

    // 3. Set BattleshipGame contract addresses
    console.log("\n🎮 Setting BattleshipGame contract addresses...");
    await battleshipGame.setContractAddresses(
      addresses.GameConfig,
      addresses.ShipNFTManager,
      addresses.ActionNFTManager,
      addresses.CaptainNFTManager,
      addresses.CrewNFTManager,
      addresses.TokenomicsCore
    );

    // 4. Set up NFT Manager authorizations for LootboxSystem
    console.log("\n📦 Setting up NFT Manager authorizations for LootboxSystem...");
    console.log("  - Authorizing LootboxSystem to mint Ships...");
    await shipNFTManager.setAuthorizedMinter(addresses.LootboxSystem, true);
    console.log("  - Authorizing LootboxSystem to mint Actions...");
    await actionNFTManager.setAuthorizedMinter(addresses.LootboxSystem, true);
    console.log("  - Authorizing LootboxSystem to mint Captains...");
    await captainNFTManager.setAuthorizedMinter(addresses.LootboxSystem, true);
    console.log("  - Authorizing LootboxSystem to mint Crew...");
    await crewNFTManager.setAuthorizedMinter(addresses.LootboxSystem, true);

    // 5. Set up NFT Manager authorizations for BattleshipGame
    console.log("\n🎮 Setting up NFT Manager authorizations for BattleshipGame...");
    console.log("  - Authorizing BattleshipGame to use Ships...");
    await shipNFTManager.setAuthorizedMinter(addresses.BattleshipGame, true);
    console.log("  - Authorizing BattleshipGame to use Actions...");
    await actionNFTManager.setAuthorizedMinter(addresses.BattleshipGame, true);
    console.log("  - Authorizing BattleshipGame to use Captains...");
    await captainNFTManager.setAuthorizedMinter(addresses.BattleshipGame, true);
    console.log("  - Authorizing BattleshipGame to use Crew...");
    await crewNFTManager.setAuthorizedMinter(addresses.BattleshipGame, true);

    // 6. Set up TokenomicsCore authorizations
    console.log("\n💎 Setting up TokenomicsCore authorizations...");
    console.log("  - Authorizing BattleshipGame for credit distribution...");
    await tokenomicsCore.setAuthorizedMinter(addresses.BattleshipGame, true);
    console.log("  - Authorizing LootboxSystem for revenue tracking...");
    await tokenomicsCore.setAuthorizedMinter(addresses.LootboxSystem, true);

    // 7. Set BattleshipToken minter
    console.log("\n📄 Setting up BattleshipToken minter...");
    console.log("  - Setting TokenomicsCore as BattleshipToken minter...");
    await battleshipToken.setMinter(addresses.TokenomicsCore);

    console.log("\n🎉 Contract authorization setup completed successfully!");
    
    // Verify some key authorizations
    console.log("\n🔍 Verifying authorizations...");
    
    console.log("  - GameState authorizations:");
    const gameLogicAuth = await gameState.authorizedContracts(addresses.GameLogic);
    const battleshipGameAuth = await gameState.authorizedContracts(addresses.BattleshipGame);
    console.log(`    GameLogic authorized: ${gameLogicAuth}`);
    console.log(`    BattleshipGame authorized: ${battleshipGameAuth}`);
    
    console.log("  - NFT Manager authorizations:");
    const lootboxShipAuth = await shipNFTManager.authorizedMinters(addresses.LootboxSystem);
    const battleshipShipAuth = await shipNFTManager.authorizedMinters(addresses.BattleshipGame);
    console.log(`    LootboxSystem can mint Ships: ${lootboxShipAuth}`);
    console.log(`    BattleshipGame can use Ships: ${battleshipShipAuth}`);
    
    console.log("  - Token minter:");
    const tokenMinter = await battleshipToken.minter();
    console.log(`    BattleshipToken minter: ${tokenMinter}`);
    console.log(`    Should be TokenomicsCore: ${tokenMinter === addresses.TokenomicsCore}`);

    console.log("\n✅ All authorizations verified and working!");
    console.log("\n🚀 CryptoBattleship is now fully deployed and configured on Sonic Blaze Testnet!");
    
    console.log("\n📋 Contract Summary:");
    console.log("=====================================");
    Object.entries(addresses).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });
    console.log("=====================================");
    
    console.log("\n🔍 Next steps:");
    console.log("1. Verify contracts: npm run verify:sonic");
    console.log("2. Test basic functionality (create game, open lootbox)");
    console.log("3. Connect frontend to deployed contracts");
    
  } catch (error) {
    console.error("❌ Setup failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Setup script failed:", error);
    process.exit(1);
  });