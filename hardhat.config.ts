import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "dotenv/config";
import "@nomicfoundation/hardhat-toolbox";
import {HardhatUserConfig} from "hardhat/config";

/** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   solidity: "0.8.24",
// };

const NEOXT4_RPC_URL = process.env.NEOXT4_RPC_URL || ""
const PRIVATE_KEY = process.env.PRIVATE_KEY



const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",

  networks: {
    hardhat: {
      accounts: {
        count: 53,
        initialIndex: 0,
        mnemonic: "test test test test test test test test test test test junk"
      },
      chainId: 31337,
      allowUnlimitedContractSize: true,
    },
    localhost: {
      chainId: 31337,
    },
    neoxt4: {
      url: NEOXT4_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY]: [],
      chainId: 12227332,
      saveDeployments: true,
    }
  },

  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    player: {
      default: 1,
    }
  },
  mocha: {     
    timeout: 500000, 
  },
}

export default config;
