import { FastifyInstance } from 'fastify';
import { poolController } from '../controllers/poolController';

// 创建池子的请求模式
const createPoolSchema = {
  body: {
    type: 'object',
    required: ['nftContractAddress', 'nftTokenIds'],
    properties: {
      nftContractAddress: { type: 'string', pattern: '^0x[a-fA-F0-9]{40}$' },
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
            nftContractAddress: { type: 'string' },
            nftTokenIds: { type: 'array', items: { type: 'number' } },
            ethAmount: { type: 'string' },
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
    required: ['nftTokenIds'],
    properties: {
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

// 获取所有池子的请求模式
const getAllPoolsSchema = {
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            pools: { type: 'array', items: { type: 'string' } },
            count: { type: 'number' },
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
          },
        },
      },
    },
  },
};

export async function poolRoutes(fastify: FastifyInstance) {
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

  // 获取所有池子
  fastify.get('/pool', {
    schema: getAllPoolsSchema,
    handler: poolController.getAllPools.bind(poolController),
  });

  // 获取池子储备量
  fastify.get('/pool/reserves', {
    schema: getPoolReservesSchema,
    handler: poolController.getPoolReserves.bind(poolController),
  });
}
