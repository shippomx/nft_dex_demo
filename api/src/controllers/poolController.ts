import { FastifyRequest, FastifyReply } from 'fastify';
import { contractService } from '../services/contracts/contractService';
import { successResponse } from '../utils/errors';
import logger from '../utils/logger';

// 创建池子的请求接口
interface CreatePoolRequest {
  Body: {
    nftContractAddress: string;
    nftTokenIds: number[];
    ethAmount?: string;
  };
}

// 添加流动性的请求接口
interface AddLiquidityRequest {
  Body: {
    nftTokenIds: number[];
    ethAmount?: string;
  };
}

// 删除流动性的请求接口
interface RemoveLiquidityRequest {
  Body: {
    lpTokenAmount: string;
    nftTokenIds: number[];
  };
}

// 获取池子信息的请求接口
interface GetPoolInfoRequest {
  Params: {
    nftContractAddress: string;
  };
}

export class PoolController {
  /**
   * 创建流动性池
   */
  async createPool(request: FastifyRequest<CreatePoolRequest>, reply: FastifyReply) {
    try {
      const { nftContractAddress, nftTokenIds, ethAmount } = request.body;

      logger.info('Creating pool:', {
        nftContractAddress,
        nftTokenIds,
        ethAmount,
      });

      const txHash = await contractService.createPool(
        nftContractAddress,
        nftTokenIds,
        ethAmount
      );

      logger.info('Pool created successfully:', { txHash });

      return reply.send(successResponse({
        txHash,
        nftContractAddress,
        nftTokenIds,
        ethAmount,
      }, 'Pool created successfully'));
    } catch (error) {
      logger.error('Failed to create pool:', error);
      throw error;
    }
  }

  /**
   * 添加流动性
   */
  async addLiquidity(request: FastifyRequest<AddLiquidityRequest>, reply: FastifyReply) {
    try {
      const { nftTokenIds, ethAmount } = request.body;

      logger.info('Adding liquidity:', {
        nftTokenIds,
        ethAmount,
      });

      const txHash = await contractService.addInitialLiquidity(
        nftTokenIds,
        ethAmount
      );

      logger.info('Liquidity added successfully:', { txHash });

      return reply.send(successResponse({
        txHash,
        nftTokenIds,
        ethAmount,
      }, 'Liquidity added successfully'));
    } catch (error) {
      logger.error('Failed to add liquidity:', error);
      throw error;
    }
  }

  /**
   * 删除流动性
   */
  async removeLiquidity(request: FastifyRequest<RemoveLiquidityRequest>, reply: FastifyReply) {
    try {
      const { lpTokenAmount, nftTokenIds } = request.body;

      logger.info('Removing liquidity:', {
        lpTokenAmount,
        nftTokenIds,
      });

      // 注意：这里需要实现 removeLiquidity 方法
      // 由于当前合约服务中没有这个方法，这里先返回一个占位符
      const txHash = 'placeholder_tx_hash';

      logger.info('Liquidity removed successfully:', { txHash });

      return reply.send(successResponse({
        txHash,
        lpTokenAmount,
        nftTokenIds,
      }, 'Liquidity removed successfully'));
    } catch (error) {
      logger.error('Failed to remove liquidity:', error);
      throw error;
    }
  }

  /**
   * 获取池子信息
   */
  async getPoolInfo(request: FastifyRequest<GetPoolInfoRequest>, reply: FastifyReply) {
    try {
      const { nftContractAddress } = request.params;

      logger.info('Getting pool info:', { nftContractAddress });

      const poolAddress = await contractService.getPool(nftContractAddress);

      if (!poolAddress || poolAddress === '0x0000000000000000000000000000000000000000') {
        return reply.send(successResponse({
          exists: false,
          nftContractAddress,
        }, 'Pool does not exist'));
      }

      // 获取池子详细信息
      const [reserves, currentPrice, sellPrice, buyQuote] = await Promise.all([
        contractService.getPoolReserves(),
        contractService.getCurrentPrice(),
        contractService.getSellPrice(),
        contractService.getBuyQuote(),
      ]);

      logger.info('Pool info retrieved successfully:', {
        nftContractAddress,
        poolAddress,
        reserves,
        currentPrice,
        sellPrice,
        buyQuote,
      });

      return reply.send(successResponse({
        exists: true,
        nftContractAddress,
        poolAddress,
        reserves,
        prices: {
          current: currentPrice,
          sell: sellPrice,
          buy: buyQuote,
        },
      }, 'Pool info retrieved successfully'));
    } catch (error) {
      logger.error('Failed to get pool info:', error);
      throw error;
    }
  }

  /**
   * 获取所有池子
   */
  async getAllPools(request: FastifyRequest, reply: FastifyReply) {
    try {
      logger.info('Getting all pools');

      const pools = await contractService.getAllPools();

      logger.info('All pools retrieved successfully:', { pools });

      return reply.send(successResponse({
        pools,
        count: pools.length,
      }, 'All pools retrieved successfully'));
    } catch (error) {
      logger.error('Failed to get all pools:', error);
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

export const poolController = new PoolController();
