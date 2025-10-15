import { ethers } from 'ethers';
import { web3Service } from '../web3Service';
import { StandardNFT_ABI, Pair_ABI, PairFactory_ABI } from './abis';
import { ContractError, BlockchainError } from '../../utils/errors';
import { bytecodeLoader, ContractInfo } from './bytecodeLoader';
import logger from '../../utils/logger';

export interface ContractAddresses {
  nftContract?: string;
  pairContract?: string;
  pairFactory?: string;
}

export interface TradeInfo {
  trader: string;
  isBuy: boolean;
  price: string;
  timestamp: number;
}

export interface PoolReserves {
  ethReserve: string;
  nftReserve: number;
  totalLiquidity: string;
  lpTokens: string;
}

export interface BuyQuote {
  totalCost: string;
  fee: string;
}

export class ContractService {
  private addresses: ContractAddresses;

  constructor(addresses: ContractAddresses = {}) {
    this.addresses = addresses;
  }

  /**
   * 更新合约地址
   */
  updateAddresses(addresses: ContractAddresses): void {
    this.addresses = { ...this.addresses, ...addresses };
    logger.info('Contract addresses updated:', this.addresses);
  }

  /**
   * 获取合约地址
   */
  getAddresses(): ContractAddresses {
    return { ...this.addresses };
  }

  // ==================== NFT 合约方法 ====================

  /**
   * 部署 NFT 合约
   */
  async deployNFTContract(
    name: string,
    symbol: string,
    baseURI: string,
    maxSupply: number,
    maxMintPerAddress: number,
    mintPrice: string
  ): Promise<string> {
    try {
      logger.info('Deploying NFT contract:', {
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        mintPrice,
      });

      // 从 Foundry 编译输出加载合约字节码
      logger.info('Loading contract bytecode...');
      const contractInfo = await bytecodeLoader.loadContract('StandardNFT');
      logger.info('Contract bytecode loaded:', {
        contractName: contractInfo.contractName,
        bytecodeLength: contractInfo.bytecode.length,
        abiLength: contractInfo.abi.length
      });
      
      logger.info('Creating contract factory...');
      const factory = new ethers.ContractFactory(
        contractInfo.abi,
        contractInfo.bytecode,
        web3Service.getSigner()
      );

      logger.info('Deploying contract...');
      const contract = await factory.deploy(
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        ethers.parseEther(mintPrice) // 将 ETH 转换为 Wei
      );

      logger.info('Waiting for deployment...');
      await contract.waitForDeployment();
      const address = await contract.getAddress();

      this.addresses.nftContract = address;
      logger.info('NFT contract deployed:', { address });

      // 注意：NFT 铸造将在部署后通过单独的 API 调用进行
      logger.info('NFT contract deployed successfully. Use /api/v1/trade/mint to mint NFTs.');

      return address;
    } catch (error) {
      logger.error('Failed to deploy NFT contract:', {
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
        name: error instanceof Error ? error.name : undefined
      });
      throw new ContractError(`Failed to deploy NFT contract: ${error instanceof Error ? error.message : String(error)}`);
    }
  }



  // ==================== Pair 合约方法 ====================

  /**
   * 部署 Pair 合约
   */
  async deployPairContract(nftContractAddress: string): Promise<string> {
    try {
      logger.info('Deploying Pair contract:', { nftContractAddress });

      // 从 Foundry 编译输出加载合约字节码
      const contractInfo = await bytecodeLoader.loadContract('Pair');
      
      const factory = new ethers.ContractFactory(
        contractInfo.abi,
        contractInfo.bytecode,
        web3Service.getSigner()
      );

      const contract = await factory.deploy(nftContractAddress);
      await contract.waitForDeployment();
      const address = await contract.getAddress();

      this.addresses.pairContract = address;
      logger.info('Pair contract deployed:', { address });

      return address;
    } catch (error) {
      logger.error('Failed to deploy Pair contract:', error);
      throw new ContractError(`Failed to deploy Pair contract: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 添加初始流动性
   */
  async addInitialLiquidity(nftTokenIds: number[], ethAmount?: string): Promise<string> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const tx = await web3Service.callContractWrite(
        this.addresses.pairContract,
        Pair_ABI as any,
        'addInitialLiquidity',
        [nftTokenIds],
        ethAmount
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      return receipt.hash;
    } catch (error) {
      logger.error('Failed to add initial liquidity:', error);
      throw new ContractError(`Failed to add initial liquidity: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 买入 NFT
   */
  async buyNFT(maxPrice: string): Promise<string> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const tx = await web3Service.callContractWrite(
        this.addresses.pairContract,
        Pair_ABI as any,
        'buyNFT',
        [maxPrice],
        maxPrice
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      return receipt.hash;
    } catch (error) {
      logger.error('Failed to buy NFT:', error);
      throw new ContractError(`Failed to buy NFT: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 卖出 NFT
   */
  async sellNFT(tokenId: number, minPrice: string): Promise<string> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const tx = await web3Service.callContractWrite(
        this.addresses.pairContract,
        Pair_ABI as any,
        'sellNFT',
        [tokenId, minPrice]
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      return receipt.hash;
    } catch (error) {
      logger.error('Failed to sell NFT:', error);
      throw new ContractError(`Failed to sell NFT: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取当前价格
   */
  async getCurrentPrice(): Promise<string> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const price = await web3Service.callContract(
        this.addresses.pairContract,
        Pair_ABI as any,
        'getCurrentPrice'
      );

      return ethers.formatEther(price);
    } catch (error) {
      logger.error('Failed to get current price:', error);
      throw new ContractError(`Failed to get current price: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取卖出价格
   */
  async getSellPrice(): Promise<string> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const price = await web3Service.callContract(
        this.addresses.pairContract,
        Pair_ABI as any,
        'getSellPrice'
      );

      return ethers.formatEther(price);
    } catch (error) {
      logger.error('Failed to get sell price:', error);
      throw new ContractError(`Failed to get sell price: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取买入报价
   */
  async getBuyQuote(): Promise<BuyQuote> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const [totalCost, fee] = await web3Service.callContract(
        this.addresses.pairContract,
        Pair_ABI as any,
        'getBuyQuote'
      );

      return {
        totalCost: ethers.formatEther(totalCost),
        fee: ethers.formatEther(fee),
      };
    } catch (error) {
      logger.error('Failed to get buy quote:', error);
      throw new ContractError(`Failed to get buy quote: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取池子储备量
   */
  async getPoolReserves(): Promise<PoolReserves> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const [ethReserve, nftReserve] = await web3Service.callContract(
        this.addresses.pairContract,
        Pair_ABI as any,
        'getPoolReserves'
      );

      // 获取LP代币总供应量
      const lpTokenAddress = await web3Service.callContract(
        this.addresses.pairContract,
        Pair_ABI as any,
        'lpToken'
      );

      const totalSupply = await web3Service.callContract(
        lpTokenAddress,
        ['function totalSupply() public view returns (uint256)'],
        'totalSupply'
      );

      // 计算总流动性（ETH储备量）
      const totalLiquidity = ethers.formatEther(ethReserve);

      return {
        ethReserve: ethers.formatEther(ethReserve),
        nftReserve: Number(nftReserve),
        totalLiquidity: totalLiquidity,
        lpTokens: ethers.formatEther(totalSupply),
      };
    } catch (error) {
      logger.error('Failed to get pool reserves:', error);
      throw new ContractError(`Failed to get pool reserves: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取交易历史
   */
  async getTradeHistory(): Promise<TradeInfo[]> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const trades = await web3Service.callContract(
        this.addresses.pairContract,
        Pair_ABI as any,
        'getTradeHistory'
      );

      return trades.map((trade: any) => ({
        trader: trade.trader,
        isBuy: trade.isBuy,
        price: ethers.formatEther(trade.price),
        timestamp: Number(trade.timestamp),
      }));
    } catch (error) {
      logger.error('Failed to get trade history:', error);
      throw new ContractError(`Failed to get trade history: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取最近交易
   */
  async getRecentTrades(count: number): Promise<TradeInfo[]> {
    if (!this.addresses.pairContract) {
      throw new ContractError('Pair contract address not set');
    }

    try {
      const trades = await web3Service.callContract(
        this.addresses.pairContract,
        Pair_ABI as any,
        'getRecentTrades',
        [count]
      );

      return trades.map((trade: any) => ({
        trader: trade.trader,
        isBuy: trade.isBuy,
        price: ethers.formatEther(trade.price),
        timestamp: Number(trade.timestamp),
      }));
    } catch (error) {
      logger.error('Failed to get recent trades:', error);
      throw new ContractError(`Failed to get recent trades: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // ==================== PairFactory 合约方法 ====================

  /**
   * 部署 PairFactory 合约
   */
  async deployPairFactory(): Promise<string> {
    try {
      logger.info('Deploying PairFactory contract');

      // 从 Foundry 编译输出加载合约字节码
      const contractInfo = await bytecodeLoader.loadContract('PairFactory');
      
      const factory = new ethers.ContractFactory(
        contractInfo.abi,
        contractInfo.bytecode,
        web3Service.getSigner()
      );

      const contract = await factory.deploy();
      await contract.waitForDeployment();
      const address = await contract.getAddress();

      this.addresses.pairFactory = address;
      logger.info('PairFactory contract deployed:', { address });

      return address;
    } catch (error) {
      logger.error('Failed to deploy PairFactory contract:', error);
      throw new ContractError(`Failed to deploy PairFactory contract: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 创建新池子
   */
  async createPool(nftContractAddress: string): Promise<{ txHash: string; poolAddress: string }> {
    if (!this.addresses.pairFactory) {
      throw new ContractError('PairFactory contract address not set');
    }

    try {
      const tx = await web3Service.callContractWrite(
        this.addresses.pairFactory,
        PairFactory_ABI as any,
        'createPool',
        [nftContractAddress]
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      
      // 从事件日志中获取池子地址
      let poolAddress = '';
      if (receipt && receipt.logs) {
        for (const log of receipt.logs) {
          try {
            const parsedLog = web3Service.parseLog(log, PairFactory_ABI);
            if (parsedLog && parsedLog.name === 'PoolCreated') {
              poolAddress = parsedLog.args.poolAddress;
              logger.info('Pool address extracted from event:', { poolAddress });
              break;
            }
          } catch (e) {
            // 忽略解析错误，继续查找
          }
        }
      }

      // 如果无法从事件中获取，尝试直接调用合约方法
      if (!poolAddress) {
        try {
          poolAddress = await web3Service.callContract(
            this.addresses.pairFactory,
            PairFactory_ABI as any,
            'getPoolAddress',
            [nftContractAddress]
          );
          logger.info('Pool address retrieved from contract:', { poolAddress });
        } catch (e) {
          logger.warn('Failed to get pool address from contract:', e);
        }
      }

      // 存储池子地址
      if (poolAddress) {
        this.addresses.pairContract = poolAddress;
        logger.info('Pool address stored:', { poolAddress });
      }

      return {
        txHash: receipt.hash,
        poolAddress: poolAddress || ''
      };
    } catch (error) {
      logger.error('Failed to create pool:', error);
      throw new ContractError(`Failed to create pool: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 授权NFT给池子
   */
  async approveNFT(nftContractAddress: string, poolAddress: string, tokenId: number): Promise<string> {
    try {
      const tx = await web3Service.callContractWrite(
        nftContractAddress,
        StandardNFT_ABI as any,
        'approve',
        [poolAddress, tokenId]
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      return receipt.hash;
    } catch (error) {
      logger.error('Failed to approve NFT:', error);
      throw new ContractError(`Failed to approve NFT: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 批量授权NFT给池子
   */
  async batchApproveNFT(nftContractAddress: string, poolAddress: string, tokenIds: number[]): Promise<string[]> {
    const txHashes: string[] = [];
    
    for (const tokenId of tokenIds) {
      try {
        const txHash = await this.approveNFT(nftContractAddress, poolAddress, tokenId);
        txHashes.push(txHash);
      } catch (error) {
        logger.error(`Failed to approve NFT ${tokenId}:`, error);
        throw new ContractError(`Failed to approve NFT ${tokenId}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
    
    return txHashes;
  }

  /**
   * 添加流动性到池子
   */
  async addLiquidityToPool(poolAddress: string, nftTokenIds: number[], ethAmount?: string): Promise<string> {
    try {
      const tx = await web3Service.callContractWrite(
        poolAddress,
        Pair_ABI as any,
        'addInitialLiquidity',
        [nftTokenIds],
        ethAmount
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      return receipt.hash;
    } catch (error) {
      logger.error('Failed to add liquidity to pool:', error);
      throw new ContractError(`Failed to add liquidity to pool: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取池子地址
   */
  async getPool(nftContractAddress: string): Promise<string> {
    if (!this.addresses.pairFactory) {
      throw new ContractError('PairFactory contract address not set');
    }

    try {
      const poolAddress = await web3Service.callContract(
        this.addresses.pairFactory,
        PairFactory_ABI as any,
        'getPoolAddress',
        [nftContractAddress]
      );

      return poolAddress;
    } catch (error) {
      logger.error('Failed to get pool:', error);
      throw new ContractError(`Failed to get pool: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // ==================== 通用部署方法 ====================




  /**
   * 清除字节码缓存
   */
  clearBytecodeCache(): void {
    bytecodeLoader.clearCache();
    logger.info('Bytecode cache cleared');
  }

  /**
   * 铸造 NFT（使用批量铸造优化）
   */
  async mintNFTs(nftContractAddress: string, amount: number, recipient?: string): Promise<{
    txHashes: string[];
    tokenIds: number[];
    totalCost: string;
    recipient: string;
  }> {
    try {
      // 使用指定的接收者或默认为部署者地址
      const mintRecipient = recipient || web3Service.getWalletAddress();
      
      logger.info('Minting NFTs using batch mint:', { nftContractAddress, amount, recipient: mintRecipient });

      // 使用静态 ABI 创建合约实例
      const contract = new ethers.Contract(
        nftContractAddress,
        StandardNFT_ABI,
        web3Service.getSigner()
      );

      // 获取铸造价格
      const mintPrice = await contract.mintPrice();
      const totalCost = mintPrice * BigInt(amount);

      // 准备批量铸造的 URI 数组
      const uris = [];
      for (let i = 1; i <= amount; i++) {
        uris.push(`https://api.test.com/metadata/${i}`);
      }

      // 使用批量铸造功能
      const batchMintTx = await (contract as any).batchMint(mintRecipient, uris, {
        value: totalCost
      });

      logger.info('Batch mint transaction sent:', {
        txHash: batchMintTx.hash,
        recipient: mintRecipient,
        amount,
        totalCost: totalCost.toString()
      });

      // 等待交易确认
      const receipt = await batchMintTx.wait();
      logger.info('Batch mint transaction confirmed:', {
        txHash: batchMintTx.hash,
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString()
      });

      // 从 BatchMinted 事件中获取 tokenIds
      let tokenIds = [];
      if (receipt && receipt.logs) {
        for (const log of receipt.logs) {
          try {
            const parsedLog = contract.interface.parseLog(log);
            if (parsedLog && parsedLog.name === 'BatchMinted') {
              // BatchMinted 事件: to, tokenIds
              tokenIds = parsedLog.args.tokenIds.map((id: any) => parseInt(id.toString()));
              logger.info('Extracted tokenIds from BatchMinted event:', { tokenIds });
              break;
            }
          } catch (e) {
            // 忽略解析错误，继续查找
          }
        }
      }

      // 如果无法从事件中获取 tokenIds，使用递增的 ID（作为后备）
      if (tokenIds.length === 0) {
        logger.warn('Could not extract tokenIds from BatchMinted event, using fallback IDs');
        for (let i = 1; i <= amount; i++) {
          tokenIds.push(i);
        }
      }

      return {
        txHashes: [batchMintTx.hash],
        tokenIds,
        totalCost: ethers.formatEther(totalCost),
        recipient: mintRecipient
      };
    } catch (error) {
      logger.error('Failed to batch mint NFTs:', error);
      throw new ContractError(`Failed to batch mint NFTs: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取字节码缓存状态
   */
  getBytecodeCacheStatus(): { size: number; keys: string[] } {
    return bytecodeLoader.getCacheStatus();
  }
}

// 创建单例实例
export const contractService = new ContractService();
