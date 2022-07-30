// https://github.com/wighawag/hardhat-deploy#2-extra-hardhatconfig-networks-options
import "dotenv/config";
import { HardhatUserConfig } from "hardhat/types";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-interface-generator";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: +process.env.LOCAL_CHAINID!,
      saveDeployments: false,
      gasPrice: 200000000000,
      gas: 30000000,
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/7p4KzWgfAW2gU_4xOoPT5mpxDdOgFycO"
      }
    },
    testnet: {
      url: process.env.TEST_URI,
      chainId: +process.env.TEST_CHAINID!,
      accounts: [`${process.env.TEST_PRIVATE_KEY}`],
      timeout: 600000,
      gasPrice: 2000000000,
      gas: 8000000,
      saveDeployments: false,
    },
    mainnet: {
      url: process.env.MAIN_URI,
      chainId: +process.env.MAIN_CHAINID!,
      accounts: [`${process.env.MAIN_PRIVATE_KEY}`],
      timeout: 600000,
      gasPrice: 2000000000,
      gas: 8000000,
      saveDeployments: true,
    }
  },
  paths: {
    sources: "./src/contracts",
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
  namedAccounts: {
    deployer: 0,
    WETH: {
      mainnet: '0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB',
      testnet: '0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB'
    },
    TREASURY: {
      default: '0x511fEFE374e9Cb50baF1E3f2E076c94b3eF8B03b',
      testnet: '0x511fEFE374e9Cb50baF1E3f2E076c94b3eF8B03b'
    },
    UNISWAP_V2_FACTORY: {
      hardhat: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
      testnet: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
      mainnet: '0xc66F594268041dB60507F00703b152492fb176E7',
    },
  },
};

export default config;
