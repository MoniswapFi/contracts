import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-ganache";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "@xyrusworx/hardhat-solidity-json";

import dotenv from "dotenv";

import { type HardhatUserConfig } from "hardhat/config";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      blockGasLimit: 400807922
    },
    local: {
      url: "http://localhost:8545",
      accounts: ["0x9bce709a035954deb674a4538ac91cf90518777c98d608c008a31ef700814ffd"], // Try stealing the funds in this
      chainId: 1337
    },
    beraArtio: {
      url: "https://artio.rpc.berachain.com",
      accounts: [process.env.PRIVATE_KEY as string], // Try stealing the funds in this
      chainId: 80085,
      gasPrice: "auto",
      gas: "auto",
      gasMultiplier: 1
    },
    beraBartio: {
      url: "https://bartio.rpc.berachain.com",
      accounts: [process.env.PRIVATE_KEY as string], // Try stealing the funds in this
      chainId: 80084,
      gasPrice: "auto",
      gas: "auto",
      gasMultiplier: 1
    },
    beraMainnet: {
      url: "https://rpc.berachain.com",
      accounts: [process.env.PRIVATE_KEY as string], // Try stealing the funds in this
      chainId: 80094,
      gasPrice: "auto",
      gas: "auto",
      gasMultiplier: 1
    },
    bscTestnet: {
      url: "https://rpc.ankr.com/bsc_testnet_chapel/7aa3ec98398d86e381952176c8b3db66b572761888fc42546e83e4b0e4a671ae",
      accounts: [process.env.PRIVATE_KEY as string], // Try stealing the funds in this
      chainId: 97
    },
    bepolia: {
      url: "https://bepolia.rpc.berachain.com",
      chainId: 80069,
      accounts: [process.env.PRIVATE_KEY as string],
      gasPrice: "auto",
      gas: "auto",
      gasMultiplier: 1
    }
  },
  typechain: {
    outDir: "./artifacts/types",
    target: "ethers-v5"
  },
  etherscan: {
    apiKey: {
      beraMainnet: "QJEEMJNMI4B2M3ZB52C9SI7A1R6A1S3GCG"
    },
    customChains: [
      {
        network: "beraMainnet",
        chainId: 80094,
        urls: {
          apiURL: "https://api.berascan.com/api",
          browserURL: "https://berascan.com"
        }
      }
    ]
  }
};

export default config;
