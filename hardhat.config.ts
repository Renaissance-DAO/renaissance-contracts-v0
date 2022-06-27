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
            runs: 1,  // FIXME: make FNFTSingleFactory compile w/ 2m runs
          },
        },
      },
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2_000_000,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: +process.env.AURORA_LOCAL_CHAINID!,
      saveDeployments: false,
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/7p4KzWgfAW2gU_4xOoPT5mpxDdOgFycO"
      }
    },
    aurora_testnet: {
      url: process.env.AURORA_TEST_URI,
      chainId: +process.env.AURORA_TEST_CHAINID!,
      accounts: [`${process.env.AURORA_TEST_PRIVATE_KEY}`],
      timeout: 600000,
      gasPrice: 2000000000,
      gas: 8000000,
      saveDeployments: false,
    },
    aurora_mainnet: {
      url: process.env.AURORA_MAIN_URI,
      chainId: +process.env.AURORA_MAIN_CHAINID!,
      accounts: [`${process.env.AURORA_MAIN_PRIVATE_KEY}`],
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
      aurora_mainnet: '0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB',
    },
    TREASURY: {
      default: '0x511fEFE374e9Cb50baF1E3f2E076c94b3eF8B03b',
    },
    UNISWAP_V2_FACTORY: {
      hardhat: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
      aurora_testnet: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
      aurora_mainnet: '0xc66F594268041dB60507F00703b152492fb176E7',
    },
  },
};

export default config;
