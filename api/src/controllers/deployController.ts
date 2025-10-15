import { FastifyRequest, FastifyReply } from 'fastify';
import { contractService } from '../services/contracts/contractService';
import { successResponse } from '../utils/errors';
import logger from '../utils/logger';

// 部署 NFT 合约的请求接口
interface DeployNFTRequest {
  Body: {
    name: string;
    symbol: string;
    baseURI: string;
    maxSupply: number;
    maxMintPerAddress: number;
    mintPrice: string;
  };
}

// 部署 Pair 合约的请求接口
interface DeployPairRequest {
  Body: {
    nftContractAddress: string;
  };
}

// 部署 PairFactory 合约的请求接口
interface DeployPairFactoryRequest {
  Body: {};
}

export class DeployController {
  /**
   * 部署 NFT 合约
   */
  async deployNFT(request: FastifyRequest<DeployNFTRequest>, reply: FastifyReply) {
    try {
      const { name, symbol, baseURI, maxSupply, maxMintPerAddress, mintPrice } = request.body;

      logger.info('Deploying NFT contract:', {
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        mintPrice,
      });

      const contractAddress = await contractService.deployNFTContract(
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        mintPrice
      );

      logger.info('NFT contract deployed successfully:', { contractAddress });

      return reply.send(successResponse({
        contractAddress,
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        mintPrice,
      }, 'NFT contract deployed successfully'));
    } catch (error) {
      logger.error('Failed to deploy NFT contract:', error);
      throw error;
    }
  }

  /**
   * 部署 Pair 合约
   */
  async deployPair(request: FastifyRequest<DeployPairRequest>, reply: FastifyReply) {
    try {
      const { nftContractAddress } = request.body;

      logger.info('Deploying Pair contract:', { nftContractAddress });

      const contractAddress = await contractService.deployPairContract(nftContractAddress);

      logger.info('Pair contract deployed successfully:', { contractAddress });

      return reply.send(successResponse({
        contractAddress,
        nftContractAddress,
      }, 'Pair contract deployed successfully'));
    } catch (error) {
      logger.error('Failed to deploy Pair contract:', error);
      throw error;
    }
  }

  /**
   * 部署 PairFactory 合约
   */
  async deployPairFactory(request: FastifyRequest<DeployPairFactoryRequest>, reply: FastifyReply) {
    try {
      logger.info('Deploying PairFactory contract');

      const contractAddress = await contractService.deployPairFactory();

      logger.info('PairFactory contract deployed successfully:', { contractAddress });

      return reply.send(successResponse({
        contractAddress,
      }, 'PairFactory contract deployed successfully'));
    } catch (error) {
      logger.error('Failed to deploy PairFactory contract:', error);
      throw error;
    }
  }

  /**
   * 获取已部署的合约地址
   */
  async getDeployedContracts(request: FastifyRequest, reply: FastifyReply) {
    try {
      const addresses = contractService.getAddresses();

      logger.info('Retrieved deployed contract addresses:', addresses);

      return reply.send(successResponse(addresses, 'Deployed contract addresses retrieved successfully'));
    } catch (error) {
      logger.error('Failed to get deployed contracts:', error);
      throw error;
    }
  }

  /**
   * 更新合约地址
   */
  async updateContractAddresses(request: FastifyRequest<{
    Body: {
      nftContract?: string;
      pairContract?: string;
      pairFactory?: string;
    };
  }>, reply: FastifyReply) {
    try {
      const { nftContract, pairContract, pairFactory } = request.body;

      contractService.updateAddresses({
        nftContract,
        pairContract,
        pairFactory,
      });

      logger.info('Contract addresses updated:', {
        nftContract,
        pairContract,
        pairFactory,
      });

      return reply.send(successResponse({
        nftContract,
        pairContract,
        pairFactory,
      }, 'Contract addresses updated successfully'));
    } catch (error) {
      logger.error('Failed to update contract addresses:', error);
      throw error;
    }
  }
}

export const deployController = new DeployController();
