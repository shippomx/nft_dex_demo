import { ethers } from 'ethers';
import config from '../config';
import logger from '../utils/logger';
import { BlockchainError } from '../utils/errors';

export class Web3Service {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private signer: ethers.Wallet;
  // nonce 仅用于日志记录和调试，不用于交易
  private nonce: number = 0;
  // nonce 锁，防止并发获取导致冲突
  private nonceLock: Promise<void> = Promise.resolve();

  constructor() {
    try {
      // 创建提供者
      this.provider = new ethers.JsonRpcProvider(config.blockchain.rpcUrl);
      
      // 创建钱包
      this.wallet = new ethers.Wallet(config.blockchain.privateKey, this.provider);
      this.signer = this.wallet;
      
      logger.info('Web3 service initialized', {
        rpcUrl: config.blockchain.rpcUrl,
        chainId: config.blockchain.chainId,
        walletAddress: this.wallet.address,
      });
    } catch (error) {
      logger.error('Failed to initialize Web3 service:', error);
      throw new BlockchainError('Failed to initialize Web3 connection');
    }
  }

  /**
   * 检查 RPC 端点连接状态
   * @returns 连接是否正常
   */
  async checkRpcConnection(): Promise<boolean> {
    try {
      logger.info('Checking RPC endpoint connection...', {
        rpcUrl: config.blockchain.rpcUrl,
      });

      // 尝试获取网络信息
      const network = await this.provider.getNetwork();
      
      // 尝试获取最新区块号
      const blockNumber = await this.provider.getBlockNumber();
      
      logger.info('✅ RPC endpoint connection successful', {
        rpcUrl: config.blockchain.rpcUrl,
        chainId: network.chainId.toString(),
        expectedChainId: config.blockchain.chainId,
        latestBlock: blockNumber,
      });

      // 检查链 ID 是否匹配
      if (Number(network.chainId) !== config.blockchain.chainId) {
        logger.warn('⚠️  Chain ID mismatch!', {
          expected: config.blockchain.chainId,
          actual: Number(network.chainId),
          rpcUrl: config.blockchain.rpcUrl,
        });
      }

      return true;
    } catch (error) {
      logger.error('❌ RPC endpoint connection failed!', {
        rpcUrl: config.blockchain.rpcUrl,
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }

  /**
   * 获取提供者实例
   */
  getProvider(): ethers.JsonRpcProvider {
    return this.provider;
  }

  /**
   * 获取签名者实例
   */
  getSigner(): ethers.Wallet {
    return this.signer;
  }

  /**
   * 获取钱包地址
   */
  getWalletAddress(): string {
    return this.wallet.address;
  }



  /**
   * 估算 Gas 费用
   */
  async estimateGas(transaction: ethers.TransactionRequest): Promise<bigint> {
    try {
      return await this.provider.estimateGas(transaction);
    } catch (error) {
      logger.error('Failed to estimate gas:', error);
      throw new BlockchainError('Failed to estimate gas');
    }
  }

  /**
   * 发送交易
   */
  async sendTransaction(transaction: ethers.TransactionRequest): Promise<ethers.TransactionResponse> {
    try {
      logger.info('Sending transaction:', {
        to: transaction.to,
        value: transaction.value?.toString(),
        data: transaction.data,
      });

      const tx = await this.signer.sendTransaction(transaction);
      
      logger.info('Transaction sent:', {
        hash: tx.hash,
        to: tx.to,
        value: tx.value?.toString(),
      });

      return tx;
    } catch (error) {
      logger.error('Failed to send transaction:', error);
      throw new BlockchainError(`Failed to send transaction: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 等待交易确认
   */
  async waitForTransaction(txHash: string, confirmations: number = 1): Promise<ethers.TransactionReceipt> {
    try {
      logger.info('Waiting for transaction confirmation:', { txHash, confirmations });
      
      const receipt = await this.provider.waitForTransaction(txHash, confirmations);
      
      if (!receipt) {
        throw new BlockchainError('Transaction receipt not found');
      }

      if (receipt.status === 0) {
        throw new BlockchainError('Transaction failed');
      }

      logger.info('Transaction confirmed:', {
        hash: receipt.hash,
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString(),
      });

      return receipt;
    } catch (error) {
      logger.error('Failed to wait for transaction:', error);
      throw new BlockchainError(`Failed to wait for transaction: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 调用合约只读方法
   */
  async callContract(
    contractAddress: string,
    abi: any[],
    method: string,
    params: any[] = []
  ): Promise<any> {
    try {
      const contract = new ethers.Contract(contractAddress, abi, this.provider);
      const result = await contract[method](...params);
      

      return result;
    } catch (error) {
      logger.error('Contract call failed:', error);
      throw new BlockchainError(`Contract call failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 调用合约写入方法
   */
  async callContractWrite(
    contractAddress: string,
    abi: any[],
    method: string,
    params: any[] = [],
    value?: string
  ): Promise<ethers.TransactionResponse> {
    try {
      const contract = new ethers.Contract(contractAddress, abi, this.signer);
      
      const txOptions: any = {
        nonce: await this.getNextNonce()
      };
      if (value) {
        txOptions.value = ethers.parseEther(value);
      }

      // 处理参数中的字符串，将ETH字符串转换为BigInt
      const processedParams = params.map(param => {
        if (typeof param === 'string' && param.includes('.')) {
          // 假设包含小数点的字符串是ETH金额
          return ethers.parseEther(param);
        }
        return param;
      });

      const tx = await contract[method](...processedParams, txOptions);
      
      logger.info('Contract write transaction sent:', {
        contract: contractAddress,
        method,
        params: processedParams.map(p => p.toString()),
        nonce: txOptions.nonce,
        txHash: tx.hash,
      });

      return tx;
    } catch (error) {
      // 避免序列化BigInt，只记录错误消息
      const errorMessage = error instanceof Error ? error.message : String(error);
      logger.error('Contract write failed:', { error: errorMessage });
      throw new BlockchainError(`Contract write failed: ${errorMessage}`);
    }
  }

  /**
   * 检查合约是否已部署
   */
  async isContractDeployed(address: string): Promise<boolean> {
    try {
      const code = await this.provider.getCode(address);
      return code !== '0x';
    } catch (error) {
      logger.error('Failed to check contract deployment:', error);
      return false;
    }
  }

  /**
   * 解析事件日志
   */
  parseLog(log: any, abi: any[]): any {
    try {
      const contract = new ethers.Contract('0x0000000000000000000000000000000000000000', abi, this.provider);
      return contract.interface.parseLog(log);
    } catch (error) {
      logger.error('Failed to parse log:', error);
      return null;
    }
  }

  /**
   * 获取下一个 nonce（带锁机制防止并发冲突）
   * 每次都从区块链查询最新的 nonce，不依赖缓存
   */
  async getNextNonce(): Promise<number> {
    // 等待之前的 nonce 获取操作完成
    await this.nonceLock;
    
    // 创建新的锁
    let releaseLock: () => void;
    this.nonceLock = new Promise((resolve) => {
      releaseLock = resolve as () => void;
    });
    
    try {
      // 直接从区块链获取最新的 nonce，使用 'pending' 状态确保包含待处理交易
      const currentNonce = await this.provider.getTransactionCount(this.wallet.address, 'pending');
      
      logger.info('Retrieved latest nonce from blockchain:', { 
        address: this.wallet.address,
        nonce: currentNonce,
        timestamp: new Date().toISOString()
      });
      
      // 更新缓存（仅用于日志记录）
      this.nonce = currentNonce;
      
      // 释放锁
      releaseLock!();
      
      // 直接返回从区块链查询的 nonce，不递增缓存
      return currentNonce;
    } catch (error) {
      logger.error('Failed to get nonce from blockchain:', error);
      
      // 如果查询失败，再次尝试使用 'latest' 状态
      try {
        const latestNonce = await this.provider.getTransactionCount(this.wallet.address, 'latest');
        logger.warn('Fallback to latest nonce:', { nonce: latestNonce });
        this.nonce = latestNonce;
        
        // 释放锁
        releaseLock!();
        
        return latestNonce;
      } catch (fallbackError) {
        logger.error('Fallback nonce query also failed:', fallbackError);
        
        // 释放锁
        releaseLock!();
        
        throw new BlockchainError(`Failed to get nonce: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  /**
   * 重置 nonce
   */
  async resetNonce(): Promise<void> {
    try {
      // 获取最新的nonce
      const latestNonce = await this.provider.getTransactionCount(this.wallet.address, 'pending');
      this.nonce = latestNonce;
      logger.info('Nonce reset:', { nonce: this.nonce });
    } catch (error) {
      logger.error('Failed to reset nonce:', error);
      throw new BlockchainError(`Failed to reset nonce: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}

// 创建单例实例
export const web3Service = new Web3Service();
