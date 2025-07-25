const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("💰 Funding Player 2 for Testing");
  console.log("===============================");
  
  const [deployer] = await ethers.getSigners();
  
  // Player 2 wallet
  const player2Address = "0x7f01d0DDc0061E6cc181Fdc88ba0e338e0C9BB01";
  
  console.log(`🏦 Deployer: ${deployer.address}`);
  console.log(`👤 Player 2: ${player2Address}`);
  
  const battleshipToken = await ethers.getContractAt("BattleshipToken", "0x49Dcf31d2e807F2DdC25357EBaE1C40EC29aF6Cd");
  
  try {
    // Check current balances
    const deployerSonicBalance = await deployer.provider.getBalance(deployer.address);
    const player2SonicBalance = await deployer.provider.getBalance(player2Address);
    const deployerShipBalance = await battleshipToken.balanceOf(deployer.address);
    const player2ShipBalance = await battleshipToken.balanceOf(player2Address);
    
    console.log(`\n📊 Current Balances:`);
    console.log(`🏦 Deployer: ${ethers.formatEther(deployerSonicBalance)} S, ${ethers.formatEther(deployerShipBalance)} SHIP`);
    console.log(`👤 Player 2: ${ethers.formatEther(player2SonicBalance)} S, ${ethers.formatEther(player2ShipBalance)} SHIP`);
    
    // Send Sonic tokens for gas if needed
    if (player2SonicBalance < ethers.parseEther("1")) {
      console.log(`\n⛽ Sending gas to Player 2...`);
      const gasTx = await deployer.sendTransaction({
        to: player2Address,
        value: ethers.parseEther("10") // 10 Sonic tokens for gas
      });
      await gasTx.wait();
      console.log(`✅ Sent 10 S for gas to Player 2`);
      
      const newSonicBalance = await deployer.provider.getBalance(player2Address);
      console.log(`💰 Player 2 new Sonic balance: ${ethers.formatEther(newSonicBalance)} S`);
    }
    
    // Send SHIP tokens
    console.log(`\n🚢 Sending SHIP tokens to Player 2...`);
    const shipAmount = ethers.parseEther("500"); // 500 SHIP tokens (50 lootboxes worth)
    const transferTx = await battleshipToken.transfer(player2Address, shipAmount);
    await transferTx.wait();
    console.log(`✅ Sent ${ethers.formatEther(shipAmount)} SHIP to Player 2`);
    
    // Verify final balances
    const finalPlayer2SonicBalance = await deployer.provider.getBalance(player2Address);
    const finalPlayer2ShipBalance = await battleshipToken.balanceOf(player2Address);
    
    console.log(`\n✅ Final Player 2 Balances:`);
    console.log(`⛽ Sonic: ${ethers.formatEther(finalPlayer2SonicBalance)} S`);
    console.log(`🚢 SHIP: ${ethers.formatEther(finalPlayer2ShipBalance)} SHIP`);
    
    console.log(`\n🎉 Player 2 is now funded and ready for lootbox testing!`);
    
  } catch (error) {
    console.error("❌ Funding failed:", error);
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