import { FastifyInstance } from 'fastify';
import { tradeController } from '../controllers/tradeController';

// 买入 NFT 的请求模式
const buyNFTSchema = {
  body: {
    type: 'object',
    required: ['maxPrice'],
    properties: {
      maxPrice: { type: 'string', pattern: '^[0-9]+(\\.[0-9]+)?$' },
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
            maxPrice: { type: 'string' },
            type: { type: 'string' },
          },
        },
      },
    },
  },
};

// 卖出 NFT 的请求模式
const sellNFTSchema = {
  body: {
    type: 'object',
    required: ['tokenId', 'minPrice'],
    properties: {
      tokenId: { type: 'number', minimum: 1 },
      minPrice: { type: 'string', pattern: '^[0-9]+(\\.[0-9]+)?$' },
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
            tokenId: { type: 'number' },
            minPrice: { type: 'string' },
            type: { type: 'string' },
          },
        },
      },
    },
  },
};

// 获取价格的请求模式
const getPriceSchema = {
  querystring: {
    type: 'object',
    properties: {
      type: { 
        type: 'string', 
        enum: ['current', 'sell', 'buy'],
        default: 'current'
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
};

// 获取交易历史的请求模式
const getTradeHistorySchema = {
  querystring: {
    type: 'object',
    properties: {
      limit: { type: 'string', pattern: '^[0-9]+$', default: '50' },
      offset: { type: 'string', pattern: '^[0-9]+$', default: '0' },
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
            items: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  trader: { type: 'string' },
                  isBuy: { type: 'boolean' },
                  price: { type: 'string' },
                  timestamp: { type: 'number' },
                },
              },
            },
            pagination: {
              type: 'object',
              properties: {
                total: { type: 'number' },
                page: { type: 'number' },
                limit: { type: 'number' },
                totalPages: { type: 'number' },
              },
            },
          },
        },
      },
    },
  },
};

// 获取最近交易的请求模式
const getRecentTradesSchema = {
  querystring: {
    type: 'object',
    properties: {
      count: { type: 'string', pattern: '^[0-9]+$', default: '10' },
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
            trades: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  trader: { type: 'string' },
                  isBuy: { type: 'boolean' },
                  price: { type: 'string' },
                  timestamp: { type: 'number' },
                },
              },
            },
            count: { type: 'number' },
          },
        },
      },
    },
  },
};

// 获取买入报价的请求模式
const getBuyQuoteSchema = {
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        data: {
          type: 'object',
          properties: {
            totalCost: { type: 'string' },
            fee: { type: 'string' },
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

export async function tradeRoutes(fastify: FastifyInstance) {
  // 买入 NFT
  fastify.post('/trade/buy', {
    schema: buyNFTSchema,
    handler: tradeController.buyNFT.bind(tradeController),
  });

  // 卖出 NFT
  fastify.post('/trade/sell', {
    schema: sellNFTSchema,
    handler: tradeController.sellNFT.bind(tradeController),
  });

  // 获取价格信息
  fastify.get('/trade/price', {
    schema: getPriceSchema,
    handler: tradeController.getPrice.bind(tradeController),
  });

  // 获取交易历史
  fastify.get('/trade/history', {
    schema: getTradeHistorySchema,
    handler: tradeController.getTradeHistory.bind(tradeController),
  });

  // 获取最近交易
  fastify.get('/trade/recent', {
    schema: getRecentTradesSchema,
    handler: tradeController.getRecentTrades.bind(tradeController),
  });

  // 获取买入报价
  fastify.get('/trade/quote', {
    schema: getBuyQuoteSchema,
    handler: tradeController.getBuyQuote.bind(tradeController),
  });

  // 获取池子储备量
  fastify.get('/trade/reserves', {
    schema: getPoolReservesSchema,
    handler: tradeController.getPoolReserves.bind(tradeController),
  });
}
