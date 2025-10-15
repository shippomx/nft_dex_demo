import * as dotenv from 'dotenv';

// 加载环境变量
dotenv.config();

export interface Config {
  server: {
    port: number;
    host: string;
    nodeEnv: string;
  };
  blockchain: {
    rpcUrl: string;
    chainId: number;
    privateKey: string;
  };
  contracts: {
    nftContractAddress?: string;
    pairContractAddress?: string;
    pairFactoryAddress?: string;
  };
  logging: {
    level: string;
    file?: string;
  };
  api: {
    prefix: string;
    corsOrigin: string;
  };
}

const config: Config = {
  server: {
    port: parseInt(process.env.PORT || '3000', 10),
    host: process.env.HOST || '0.0.0.0',
    nodeEnv: process.env.NODE_ENV || 'development',
  },
  blockchain: {
    rpcUrl: process.env.RPC_URL || 'http://localhost:8545',
    chainId: parseInt(process.env.CHAIN_ID || '31337', 10),
    privateKey: process.env.PRIVATE_KEY || '',
  },
  contracts: {
    nftContractAddress: process.env.NFT_CONTRACT_ADDRESS,
    pairContractAddress: process.env.PAIR_CONTRACT_ADDRESS,
    pairFactoryAddress: process.env.PAIR_FACTORY_ADDRESS,
  },
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE,
  },
  api: {
    prefix: process.env.API_PREFIX || '/api/v1',
    corsOrigin: process.env.CORS_ORIGIN || '*',
  },
};

export default config;
