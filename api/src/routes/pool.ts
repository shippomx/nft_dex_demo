import { FastifyInstance } from 'fastify';
import { poolController } from '../controllers/poolController';

// 授权NFT的请求模式
const approveNFTSchema = {
  body: {
    type: 'object',
    required: ['nftContractAddress', 'poolAddress', 'tokenId'],
    properties: {
      nftContractAddress: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
      poolAddress: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
      tokenId: { type: 'number', minimum: 1 },
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
            txHash: { type: 'string' },
            nftContractAddress: { type: 'string' },
            poolAddress: { type: 'string' },
            tokenId: { type: 'number' },
          },
        },
      },
    },
  },
};

// 批量授权NFT的请求模式
const batchApproveNFTSchema = {
  body: {
    type: 'object',
    required: ['nftContractAddress', 'poolAddress', 'tokenIds'],
    properties: {
      nftContractAddress: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
      poolAddress: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
      tokenIds: {
        type: 'array',
        items: { type: 'number', minimum: 1 },
        minItems: 1,
      },
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
            txHashes: { type: 'array', items: { type: 'string' } },
            nftContractAddress: { type: 'string' },
            poolAddress: { type: 'string' },
            tokenIds: { type: 'array', items: { type: 'number' } },
          },
        },
      },
    },
  },
};

// 创建池子的请求模式
const createPoolSchema = {
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
            txHash: { type: 'string' },
            nftContractAddress: { type: 'string' },
          },
        },
      },
    },
  },
};

// 添加流动性的请求模式
const addLiquiditySchema = {
  body: {
    type: 'object',
    required: ['poolAddress', 'nftTokenIds'],
    properties: {
      poolAddress: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
      nftTokenIds: {
        type: 'array',
        items: { type: 'number', minimum: 1 },
        minItems: 1,
      },
      ethAmount: { type: 'string', pattern: '^[0-9]+(\\.[0-9]+)?$' },
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
            txHash: { type: 'string' },
            poolAddress: { type: 'string' },
            nftTokenIds: { type: 'array', items: { type: 'number' } },
            ethAmount: { type: 'string' },
          },
        },
      },
    },
  },
};

// 删除流动性的请求模式
const removeLiquiditySchema = {
  body: {
    type: 'object',
    required: ['lpTokenAmount', 'nftTokenIds'],
    properties: {
      lpTokenAmount: { type: 'string', pattern: '^[0-9]+(\\.[0-9]+)?$' },
      nftTokenIds: {
        type: 'array',
        items: { type: 'number', minimum: 1 },
        minItems: 1,
      },
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
            txHash: { type: 'string' },
            lpTokenAmount: { type: 'string' },
            nftTokenIds: { type: 'array', items: { type: 'number' } },
          },
        },
      },
    },
  },
};

// 获取池子信息的请求模式
const getPoolInfoSchema = {
  params: {
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
            exists: { type: 'boolean' },
            nftContractAddress: { type: 'string' },
            poolAddress: { type: 'string' },
            reserves: {
              type: 'object',
              properties: {
                ethReserve: { type: 'string' },
                nftReserve: { type: 'number' },
              },
            },
            prices: {
              type: 'object',
              properties: {
                current: { type: 'string' },
                sell: { type: 'string' },
                buy: {
                  type: 'object',
                  properties: {
                    totalCost: { type: 'string' },
                    fee: { type: 'string' },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
};

// 获取池子储备量的请求模式
const getPoolReservesSchema = {
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            ethReserve: { type: 'string' },
            nftReserve: { type: 'number' },
            totalLiquidity: { type: 'string' },
            lpTokens: { type: 'string' },
          },
        },
      },
    },
  },
};

export async function poolRoutes(fastify: FastifyInstance) {
  // 授权NFT给池子
  fastify.post('/pool/approve-nft', {
    schema: approveNFTSchema,
    handler: poolController.approveNFT.bind(poolController),
  });

  // 批量授权NFT给池子
  fastify.post('/pool/batch-approve-nft', {
    schema: batchApproveNFTSchema,
    handler: poolController.batchApproveNFT.bind(poolController),
  });

  // 创建流动性池
  fastify.post('/pool/create', {
    schema: createPoolSchema,
    handler: poolController.createPool.bind(poolController),
  });

  // 添加流动性
  fastify.post('/pool/add-liquidity', {
    schema: addLiquiditySchema,
    handler: poolController.addLiquidity.bind(poolController),
  });

  // 删除流动性
  fastify.post('/pool/remove-liquidity', {
    schema: removeLiquiditySchema,
    handler: poolController.removeLiquidity.bind(poolController),
  });

  // 获取指定池子信息
  fastify.get('/pool/:nftContractAddress', {
    schema: getPoolInfoSchema,
    handler: poolController.getPoolInfo.bind(poolController),
  });

  // 获取池子储备量
  fastify.get('/pool/reserves', {
    schema: getPoolReservesSchema,
    handler: poolController.getPoolReserves.bind(poolController),
  });
}
