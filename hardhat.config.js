require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1, // Reduced runs to minimize contract size
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true,
          }
        }
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    sonicBlaze: {
      url: "https://rpc.blaze.soniclabs.com",
      chainId: 57054,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 20000000000, // 20 gwei (increased for Sonic network)
    },
  },
  etherscan: {
    // Etherscan V2 API - single API key for all networks
    apiKey: process.env.ETHERSCAN_API_KEY || "placeholder",
    customChains: [
      {
        network: "sonicBlaze",
        chainId: 57054,
        urls: {
          apiURL: "https://api.testnet.sonicscan.org/api",
          browserURL: "https://testnet.sonicscan.org/",
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
};