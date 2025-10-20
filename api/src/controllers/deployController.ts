import { FastifyRequest, FastifyReply } from 'fastify';
import { contractService } from '../services/contracts/contractService';
import { web3Service } from '../services/web3Service';
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

      const { address: contractAddress, txHash } = await contractService.deployNFTContract(
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        mintPrice
      );

      logger.info('NFT contract deployed successfully:', { contractAddress, txHash });

      // 等待 1 秒让区块链更新 nonce
      logger.info('Waiting for nonce to update...');
      await new Promise(resolve => setTimeout(resolve, 1000));

      // 自动铸造 10 个 NFT 给部署者
      logger.info('Auto-minting 10 NFTs to deployer...');
      const mintResult = await contractService.mintNFTs(contractAddress, 10);
      logger.info('NFTs minted successfully:', mintResult);

      return reply.send(successResponse({
        contractAddress,
        txHash,
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        mintPrice,
        mintedNFTs: mintResult.tokenIds.length,
        mintedTokenIds: mintResult.tokenIds,
        mintTxHashes: mintResult.txHashes,
        deployerAddress: web3Service.getWalletAddress(),
      }, `NFT contract deployed successfully with ${mintResult.tokenIds.length} NFTs minted to deployer`));
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

      const { address: contractAddress, txHash } = await contractService.deployPairContract(nftContractAddress);

      logger.info('Pair contract deployed successfully:', { contractAddress, txHash });

      return reply.send(successResponse({
        contractAddress,
        txHash,
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

      const { address: contractAddress, txHash } = await contractService.deployPairFactory();

      logger.info('PairFactory contract deployed successfully:', { contractAddress, txHash });

      return reply.send(successResponse({
        contractAddress,
        txHash,
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
