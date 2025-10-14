import { ethers } from 'ethers';
import { web3Service } from '../web3Service';
import { StandardNFT_ABI, Pair_ABI, MultiPoolManager_ABI, LPToken_ABI } from './abis';
import { ContractError, BlockchainError } from '../../utils/errors';
import { bytecodeLoader, ContractInfo } from './bytecodeLoader';
import logger from '../../utils/logger';

export interface ContractAddresses {
  nftContract?: string;
  pairContract?: string;
  multiPoolManager?: string;
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
      const contractInfo = await bytecodeLoader.loadContract('StandardNFT');
      
      const factory = new ethers.ContractFactory(
        contractInfo.abi,
        contractInfo.bytecode,
        web3Service.getSigner()
      );

      const contract = await factory.deploy(
        name,
        symbol,
        baseURI,
        maxSupply,
        maxMintPerAddress,
        ethers.parseEther(mintPrice)
      );

      await contract.waitForDeployment();
      const address = await contract.getAddress();

      this.addresses.nftContract = address;
      logger.info('NFT contract deployed:', { address });

      return address;
    } catch (error) {
      logger.error('Failed to deploy NFT contract:', error);
      throw new ContractError(`Failed to deploy NFT contract: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 铸造 NFT
   */
  async mintNFT(to: string, value?: string): Promise<string> {
    if (!this.addresses.nftContract) {
      throw new ContractError('NFT contract address not set');
    }

    try {
      const tx = await web3Service.callContractWrite(
        this.addresses.nftContract,
        StandardNFT_ABI as any,
        'mint',
        [to],
        value
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      return receipt.hash;
    } catch (error) {
      logger.error('Failed to mint NFT:', error);
      throw new ContractError(`Failed to mint NFT: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取 NFT 信息
   */
  async getNFTInfo(): Promise<{
    name: string;
    symbol: string;
    totalSupply: string;
    balance: string;
  }> {
    if (!this.addresses.nftContract) {
      throw new ContractError('NFT contract address not set');
    }

    try {
      const [name, symbol, totalSupply, balance] = await Promise.all([
        web3Service.callContract(this.addresses.nftContract, StandardNFT_ABI, 'name'),
        web3Service.callContract(this.addresses.nftContract, StandardNFT_ABI, 'symbol'),
        web3Service.callContract(this.addresses.nftContract, StandardNFT_ABI, 'totalSupply'),
        web3Service.callContract(this.addresses.nftContract, StandardNFT_ABI, 'balanceOf', [web3Service.getWalletAddress()]),
      ]);

      return {
        name,
        symbol,
        totalSupply: totalSupply.toString(),
        balance: balance.toString(),
      };
    } catch (error) {
      logger.error('Failed to get NFT info:', error);
      throw new ContractError(`Failed to get NFT info: ${error instanceof Error ? error.message : String(error)}`);
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
        [ethers.parseEther(maxPrice)],
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
        [tokenId, ethers.parseEther(minPrice)]
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

      return {
        ethReserve: ethers.formatEther(ethReserve),
        nftReserve: Number(nftReserve),
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

  // ==================== MultiPoolManager 合约方法 ====================

  /**
   * 部署 MultiPoolManager 合约
   */
  async deployMultiPoolManager(): Promise<string> {
    try {
      logger.info('Deploying MultiPoolManager contract');

      // 从 Foundry 编译输出加载合约字节码
      const contractInfo = await bytecodeLoader.loadContract('MultiPoolManager');
      
      const factory = new ethers.ContractFactory(
        contractInfo.abi,
        contractInfo.bytecode,
        web3Service.getSigner()
      );

      const contract = await factory.deploy();
      await contract.waitForDeployment();
      const address = await contract.getAddress();

      this.addresses.multiPoolManager = address;
      logger.info('MultiPoolManager contract deployed:', { address });

      return address;
    } catch (error) {
      logger.error('Failed to deploy MultiPoolManager contract:', error);
      throw new ContractError(`Failed to deploy MultiPoolManager contract: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 创建新池子
   */
  async createPool(nftContractAddress: string, nftTokenIds: number[], ethAmount?: string): Promise<string> {
    if (!this.addresses.multiPoolManager) {
      throw new ContractError('MultiPoolManager contract address not set');
    }

    try {
      const tx = await web3Service.callContractWrite(
        this.addresses.multiPoolManager,
        MultiPoolManager_ABI as any,
        'createPool',
        [nftContractAddress, nftTokenIds],
        ethAmount
      );

      const receipt = await web3Service.waitForTransaction(tx.hash);
      return receipt.hash;
    } catch (error) {
      logger.error('Failed to create pool:', error);
      throw new ContractError(`Failed to create pool: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取池子地址
   */
  async getPool(nftContractAddress: string): Promise<string> {
    if (!this.addresses.multiPoolManager) {
      throw new ContractError('MultiPoolManager contract address not set');
    }

    try {
      const poolAddress = await web3Service.callContract(
        this.addresses.multiPoolManager,
        MultiPoolManager_ABI as any,
        'getPool',
        [nftContractAddress]
      );

      return poolAddress;
    } catch (error) {
      logger.error('Failed to get pool:', error);
      throw new ContractError(`Failed to get pool: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取所有池子
   */
  async getAllPools(): Promise<string[]> {
    if (!this.addresses.multiPoolManager) {
      throw new ContractError('MultiPoolManager contract address not set');
    }

    try {
      const pools = await web3Service.callContract(
        this.addresses.multiPoolManager,
        MultiPoolManager_ABI as any,
        'getAllPools'
      );

      return pools;
    } catch (error) {
      logger.error('Failed to get all pools:', error);
      throw new ContractError(`Failed to get all pools: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // ==================== 通用部署方法 ====================

  /**
   * 动态部署合约
   * @param contractName 合约名称
   * @param constructorArgs 构造函数参数
   * @param value 发送的 ETH 值（可选）
   * @returns 部署的合约地址
   */
  async deployContract(
    contractName: string,
    constructorArgs: any[] = [],
    value?: string
  ): Promise<string> {
    try {
      logger.info('Deploying contract dynamically:', {
        contractName,
        constructorArgs,
        value,
      });

      // 从 Foundry 编译输出加载合约字节码
      const contractInfo = await bytecodeLoader.loadContract(contractName);
      
      const factory = new ethers.ContractFactory(
        contractInfo.abi,
        contractInfo.bytecode,
        web3Service.getSigner()
      );

      const deployOptions: any = {};
      if (value) {
        deployOptions.value = ethers.parseEther(value);
      }

      const contract = await factory.deploy(...constructorArgs, deployOptions);
      await contract.waitForDeployment();
      const address = await contract.getAddress();

      logger.info('Contract deployed successfully:', {
        contractName,
        address,
        constructorArgs,
      });

      return address;
    } catch (error) {
      logger.error('Failed to deploy contract:', error);
      throw new ContractError(`Failed to deploy contract ${contractName}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取可用合约列表
   * @returns 可用合约名称列表
   */
  async getAvailableContracts(): Promise<string[]> {
    try {
      return await bytecodeLoader.listAvailableContracts();
    } catch (error) {
      logger.error('Failed to get available contracts:', error);
      throw new ContractError(`Failed to get available contracts: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取合约信息
   * @param contractName 合约名称
   * @returns 合约信息
   */
  async getContractInfo(contractName: string): Promise<ContractInfo> {
    try {
      return await bytecodeLoader.loadContract(contractName);
    } catch (error) {
      logger.error('Failed to get contract info:', error);
      throw new ContractError(`Failed to get contract info for ${contractName}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 清除字节码缓存
   */
  clearBytecodeCache(): void {
    bytecodeLoader.clearCache();
    logger.info('Bytecode cache cleared');
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
