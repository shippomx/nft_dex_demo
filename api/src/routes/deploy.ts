import { FastifyInstance } from 'fastify';
import { deployController } from '../controllers/deployController';

// 部署相关的请求模式
const deployNFTSchema = {
  body: {
    type: 'object',
    required: ['name', 'symbol', 'baseURI', 'maxSupply', 'maxMintPerAddress', 'mintPrice'],
    properties: {
      name: { type: 'string', minLength: 1, maxLength: 100 },
      symbol: { type: 'string', minLength: 1, maxLength: 20 },
      baseURI: { type: 'string', format: 'uri' },
      maxSupply: { type: 'number', minimum: 1, maximum: 1000000 },
      maxMintPerAddress: { type: 'number', minimum: 1, maximum: 1000 },
      mintPrice: { type: 'string', pattern: '^[0-9]+(\\.[0-9]+)?$' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            contractAddress: { type: 'string' },
            name: { type: 'string' },
            symbol: { type: 'string' },
            baseURI: { type: 'string' },
            maxSupply: { type: 'number' },
            maxMintPerAddress: { type: 'number' },
            mintPrice: { type: 'string' },
          },
        },
      },
    },
  },
};

const deployPairSchema = {
  body: {
    type: 'object',
    required: ['nftContractAddress'],
    properties: {
      nftContractAddress: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            contractAddress: { type: 'string' },
            nftContractAddress: { type: 'string' },
          },
        },
      },
    },
  },
};

const deployMultiPoolManagerSchema = {
  body: {
    type: 'object',
    properties: {},
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            contractAddress: { type: 'string' },
          },
        },
      },
    },
  },
};

const getDeployedContractsSchema = {
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            nftContract: { type: 'string' },
            pairContract: { type: 'string' },
            multiPoolManager: { type: 'string' },
          },
        },
      },
    },
  },
};

const updateContractAddressesSchema = {
  body: {
    type: 'object',
    properties: {
      nftContract: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
      pairContract: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
      multiPoolManager: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            nftContract: { type: 'string' },
            pairContract: { type: 'string' },
            multiPoolManager: { type: 'string' },
          },
        },
      },
    },
  },
};

export async function deployRoutes(fastify: FastifyInstance) {
  // 部署 NFT 合约
  fastify.post('/deploy/nft', {
    schema: deployNFTSchema,
    handler: deployController.deployNFT.bind(deployController),
  });

  // 部署 Pair 合约
  fastify.post('/deploy/pair', {
    schema: deployPairSchema,
    handler: deployController.deployPair.bind(deployController),
  });

  // 部署 MultiPoolManager 合约
  fastify.post('/deploy/multi-pool-manager', {
    schema: deployMultiPoolManagerSchema,
    handler: deployController.deployMultiPoolManager.bind(deployController),
  });

  // 获取已部署的合约地址
  fastify.get('/deploy/contracts', {
    schema: getDeployedContractsSchema,
    handler: deployController.getDeployedContracts.bind(deployController),
  });

  // 更新合约地址
  fastify.put('/deploy/contracts', {
    schema: updateContractAddressesSchema,
    handler: deployController.updateContractAddresses.bind(deployController),
  });
}
