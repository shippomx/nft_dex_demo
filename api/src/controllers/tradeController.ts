import { FastifyRequest, FastifyReply } from 'fastify';
import { contractService } from '../services/contracts/contractService';
import { successResponse, paginatedResponse } from '../utils/errors';
import logger from '../utils/logger';

// 买入 NFT 的请求接口
interface BuyNFTRequest {
  Body: {
    maxPrice: string;
  };
}

// 卖出 NFT 的请求接口
interface SellNFTRequest {
  Body: {
    tokenId: number;
    minPrice: string;
  };
}

// 获取价格的请求接口
interface GetPriceRequest {
  Querystring: {
    type?: 'current' | 'sell' | 'buy';
  };
}

// 获取交易历史的请求接口
interface GetTradeHistoryRequest {
  Querystring: {
    limit?: string;
    offset?: string;
  };
}

export class TradeController {
  /**
   * 买入 NFT
   */
  async buyNFT(request: FastifyRequest<BuyNFTRequest>, reply: FastifyReply) {
    try {
      const { maxPrice } = request.body;

      logger.info('Buying NFT:', { maxPrice });

      const txHash = await contractService.buyNFT(maxPrice);

      logger.info('NFT bought successfully:', { txHash, maxPrice });

      return reply.send(successResponse({
        txHash,
        maxPrice,
        type: 'buy',
      }, 'NFT bought successfully'));
    } catch (error) {
      logger.error('Failed to buy NFT:', error);
      throw error;
    }
  }

  /**
   * 卖出 NFT
   */
  async sellNFT(request: FastifyRequest<SellNFTRequest>, reply: FastifyReply) {
    try {
      const { tokenId, minPrice } = request.body;

      logger.info('Selling NFT:', { tokenId, minPrice });

      const txHash = await contractService.sellNFT(tokenId, minPrice);

      logger.info('NFT sold successfully:', { txHash, tokenId, minPrice });

      return reply.send(successResponse({
        txHash,
        tokenId,
        minPrice,
        type: 'sell',
      }, 'NFT sold successfully'));
    } catch (error) {
      logger.error('Failed to sell NFT:', error);
      throw error;
    }
  }

  /**
   * 获取价格信息
   */
  async getPrice(request: FastifyRequest<GetPriceRequest>, reply: FastifyReply) {
    try {
      const { type = 'current' } = request.query;

      logger.info('Getting price:', { type });

      let priceData: any = {};

      switch (type) {
        case 'current':
          priceData.current = await contractService.getCurrentPrice();
          break;
        case 'sell':
          priceData.sell = await contractService.getSellPrice();
          break;
        case 'buy':
          priceData.buy = await contractService.getBuyQuote();
          break;
        default:
          // 获取所有价格信息
          const [current, sell, buy] = await Promise.all([
            contractService.getCurrentPrice(),
            contractService.getSellPrice(),
            contractService.getBuyQuote(),
          ]);
          priceData = { current, sell, buy };
      }

      logger.info('Price retrieved successfully:', { type, priceData });

      return reply.send(successResponse(priceData, 'Price retrieved successfully'));
    } catch (error) {
      logger.error('Failed to get price:', error);
      throw error;
    }
  }

  /**
   * 获取交易历史
   */
  async getTradeHistory(request: FastifyRequest<GetTradeHistoryRequest>, reply: FastifyReply) {
    try {
      const { limit = '50', offset = '0' } = request.query;
      const limitNum = parseInt(limit, 10);
      const offsetNum = parseInt(offset, 10);

      logger.info('Getting trade history:', { limit: limitNum, offset: offsetNum });

      const trades = await contractService.getTradeHistory();
      const total = trades.length;

      // 分页处理
      const startIndex = offsetNum;
      const endIndex = Math.min(startIndex + limitNum, total);
      const paginatedTrades = trades.slice(startIndex, endIndex);

      logger.info('Trade history retrieved successfully:', {
        total,
        returned: paginatedTrades.length,
        limit: limitNum,
        offset: offsetNum,
      });

      return reply.send(paginatedResponse(
        paginatedTrades,
        total,
        Math.floor(offsetNum / limitNum) + 1,
        limitNum,
        'Trade history retrieved successfully'
      ));
    } catch (error) {
      logger.error('Failed to get trade history:', error);
      throw error;
    }
  }

  /**
   * 获取最近交易
   */
  async getRecentTrades(request: FastifyRequest<{
    Querystring: {
      count?: string;
    };
  }>, reply: FastifyReply) {
    try {
      const { count = '10' } = request.query;
      const countNum = parseInt(count, 10);

      logger.info('Getting recent trades:', { count: countNum });

      const trades = await contractService.getRecentTrades(countNum);

      logger.info('Recent trades retrieved successfully:', {
        count: trades.length,
        requested: countNum,
      });

      return reply.send(successResponse({
        trades,
        count: trades.length,
      }, 'Recent trades retrieved successfully'));
    } catch (error) {
      logger.error('Failed to get recent trades:', error);
      throw error;
    }
  }

  /**
   * 获取买入报价
   */
  async getBuyQuote(request: FastifyRequest, reply: FastifyReply) {
    try {
      logger.info('Getting buy quote');

      const quote = await contractService.getBuyQuote();

      logger.info('Buy quote retrieved successfully:', quote);

      return reply.send(successResponse(quote, 'Buy quote retrieved successfully'));
    } catch (error) {
      logger.error('Failed to get buy quote:', error);
      throw error;
    }
  }

  /**
   * 获取池子储备量
   */
  async getPoolReserves(request: FastifyRequest, reply: FastifyReply) {
    try {
      logger.info('Getting pool reserves');

      const reserves = await contractService.getPoolReserves();

      logger.info('Pool reserves retrieved successfully:', reserves);

      return reply.send(successResponse(reserves, 'Pool reserves retrieved successfully'));
    } catch (error) {
      logger.error('Failed to get pool reserves:', error);
      throw error;
    }
  }
}

export const tradeController = new TradeController();
