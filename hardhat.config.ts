import "@nomicfoundation/hardhat-toolbox";
import { config as dotenvConfig } from "dotenv";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import type { HardhatUserConfig } from "hardhat/config";
import { resolve } from "path";

import "./tasks/accounts";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

function getMnemonic(networkName?: string) {
  if (networkName) {
    const mnemonic = process.env["MNEMONIC_" + networkName.toUpperCase()];
    if (mnemonic && mnemonic !== "") {
      return mnemonic;
    }
  }

  const mnemonic = process.env.MNEMONIC;
  if (!mnemonic || mnemonic === "") {
    return "test test test test test test test test test test test junk";
  }

  return mnemonic;
}

function accounts(networkName?: string) {
  return { mnemonic: getMnemonic(networkName) };
}

// Etherscan API keys and -urls
const apiKeys: Record<string, string> = {
  ethereum: process.env.ETHERSCAN_ONLY_API_KEY || "",
  goerli: process.env.ETHERSCAN_ONLY_API_KEY || "",
  sepolia: process.env.ETHERSCAN_ONLY_API_KEY || "",
  bsc: process.env.BSCSCAN_API_KEY || "",
  "bsc-testnet": process.env.BSCSCAN_API_KEY || "",
  avalanche: process.env.SNOWTRACE_API_KEY || "",
  fuji: process.env.SNOWTRACE_API_KEY || "",
  polygon: process.env.POLYGONSCAN_API_KEY || "",
  mumbai: process.env.POLYGONSCAN_API_KEY || "",
  fantom: process.env.FANTOMSCAN_API_KEY || "",
  "fantom-testnet": process.env.FANTOMSCAN_API_KEY || "",
  optimism: process.env.OPTIMISM_API_KEY || "",
  "optimism-goerli": process.env.OPTIMISM_API_KEY || "",
  "arbitrum-goerli": process.env.ARBISCAN_API_KEY || "",
  arbitrum: process.env.ARBISCAN_API_KEY || "",
  "imtbl-zkevm-testnet": "a",
  "imtbl-zkevm": "a",
};

const apiUrls: Record<string, string> = {
  ethereum: "https://api.etherscan.io",
  goerli: "https://api-goerli.etherscan.io",
  sepolia: "https://api-sepolia.etherscan.io",
  bsc: "https://api.bscscan.com",
  "bsc-testnet": "https://api-testnet.bscscan.com",
  avalanche: "https://api.snowtrace.io",
  fuji: "https://api-testnet.snowtrace.io",
  polygon: "https://api.polygonscan.com",
  mumbai: "https://api-testnet.polygonscan.com",
  fantom: "https://api.ftmscan.com",
  "fantom-testnet": "https://api-testnet.ftmscan.com",
  optimism: "https://api-optimistic.etherscan.io",
  "optimism-goerli": "https://api-goerli-optimistic.etherscan.io",
  arbitrum: "https://api.arbiscan.io",
  "arbitrum-goerli": "https://api-goerli.arbiscan.io",
  "imtbl-zkevm-testnet": "https://explorer.testnet.immutable.com/api",
  "imtbl-zkevm": "https://explorer.immutable.com/api",
};

// `hardhat-deploy etherscan-verify` network config
function verifyChain(networkName: string) {
  return {
    etherscan: {
      apiKey: apiKeys[networkName] || undefined,
      apiUrls: apiUrls[networkName] || undefined,
    },
  };
}

// `hardhat verify` network config
function customChain(networkName: string) {
  return {
    network: networkName,
    chainId: networks[networkName] ? networks[networkName].chainId : -1,
    urls: {
      apiURL: apiUrls[networkName] ? `${apiUrls[networkName]}/api` : "",
      browserURL: apiUrls[networkName] ? apiUrls[networkName].replace("api.", "").replace("api-", "") : "",
    },
  };
}

const networks: Record<string, any> = {
  // mainnets
  ethereum: {
    url: "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161", // public infura endpoint
    chainId: 1,
    accounts: accounts(),
    verify: verifyChain("ethereum"),
  },
  bsc: {
    url: "https://bsc-dataseed1.binance.org",
    chainId: 56,
    accounts: accounts(),
    verify: verifyChain("bsc"),
  },
  avalanche: {
    url: "https://api.avax.network/ext/bc/C/rpc",
    chainId: 43114,
    accounts: accounts(),
    verify: verifyChain("avalanche"),
  },
  polygon: {
    url: "https://rpc-mainnet.maticvigil.com",
    chainId: 137,
    accounts: accounts(),
    verify: verifyChain("polygon"),
  },
  arbitrum: {
    url: "https://arb1.arbitrum.io/rpc",
    chainId: 42161,
    accounts: accounts(),
    verify: verifyChain("arbitrum"),
  },
  optimism: {
    url: "https://mainnet.optimism.io",
    chainId: 10,
    accounts: accounts(),
    verify: verifyChain("optimism"),
  },
  fantom: {
    url: "https://rpcapi.fantom.network",
    chainId: 250,
    accounts: accounts(),
    verify: verifyChain("fantom"),
  },
  metis: {
    url: "https://andromeda.metis.io/?owner=1088",
    chainId: 1088,
    accounts: accounts(),
  },
  beam: {
    url: "https://subnets.avax.network/beam/mainnet/rpc",
    chainId: 4337,
    accounts: accounts(),
  },
  "imtbl-zkevm": {
    url: "https://rpc.immutable.com",
    chainId: 13371,
    accounts: accounts(),
    verify: verifyChain("imtbl-zkevm"),
  },

  // testnets
  goerli: {
    url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161", // public infura endpoint
    chainId: 5,
    accounts: accounts(),
    verify: verifyChain("goerli"),
  },
  sepolia: {
    url: "https://ethereum-sepolia.publicnode.com",
    chainId: 11155111,
    accounts: accounts(),
    verify: verifyChain("sepolia"),
  },
  "bsc-testnet": {
    url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
    chainId: 97,
    accounts: accounts(),
    verify: verifyChain("bsc-testnet"),
  },
  fuji: {
    url: "https://api.avax-test.network/ext/bc/C/rpc",
    chainId: 43113,
    accounts: accounts(),
    verify: verifyChain("fuji"),
  },
  mumbai: {
    url: "https://rpc-mumbai.maticvigil.com/",
    chainId: 80001,
    accounts: accounts(),
    verify: verifyChain("mumbai"),
  },
  "arbitrum-goerli": {
    url: "https://goerli-rollup.arbitrum.io/rpc/",
    chainId: 421613,
    accounts: accounts(),
    verify: verifyChain("arbitrum-goerli"),
  },
  "optimism-goerli": {
    url: "https://goerli.optimism.io/",
    chainId: 420,
    accounts: accounts(),
    verify: verifyChain("optimism-goerli"),
  },
  "fantom-testnet": {
    url: "https://rpc.ankr.com/fantom_testnet",
    chainId: 4002,
    accounts: accounts(),
    verify: verifyChain("fantom-testnet"),
  },
  "beam-testnet": {
    url: "https://subnets.avax.network/beam/testnet/rpc",
    chainId: 13337,
    accounts: accounts(),
  },
  "imtbl-zkevm-testnet": {
    url: "https://rpc.testnet.immutable.com",
    chainId: 13473,
    accounts: accounts(),
    verify: verifyChain("imtbl-zkevm-testnet"),
  },
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: 0,
  },
  //`hardhat verify` config
  etherscan: {
    apiKey: apiKeys,
    customChains: Object.keys(apiUrls).map((networkName) => customChain(networkName)),
  },
  gasReporter: {
    currency: "USD",
    enabled: !!process.env.REPORT_GAS,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      accounts: accounts(),
      chainId: 31337,
    },
    ganache: {
      accounts: accounts(),
      chainId: 1337,
      url: "http://localhost:8545",
    },
    ...networks,
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    compilers: [
      {
        version: "0.8.25",
        settings: {
          evmVersion: "paris",
          metadata: {
            // Not including the metadata hash
            // https://github.com/paulrberg/hardhat-template/issues/31
            bytecodeHash: "none",
          },
          // Disable the optimizer when debugging
          // https://hardhat.org/hardhat-network/#solidity-optimizer-support
          optimizer: {
            enabled: true,
            runs: 1000000000,
          },
        },
      },
    ],
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },
};

export default config;
