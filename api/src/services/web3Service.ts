import { ethers } from 'ethers';
import config from '../config';
import logger from '../utils/logger';
import { BlockchainError } from '../utils/errors';

export class Web3Service {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private signer: ethers.Wallet;

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
   * 获取网络信息
   */
  async getNetworkInfo() {
    try {
      const network = await this.provider.getNetwork();
      const blockNumber = await this.provider.getBlockNumber();
      const feeData = await this.provider.getFeeData();
      const gasPrice = feeData.gasPrice || BigInt(0);
      
      return {
        chainId: Number(network.chainId),
        name: network.name,
        blockNumber,
        gasPrice: gasPrice.toString(),
      };
    } catch (error) {
      logger.error('Failed to get network info:', error);
      throw new BlockchainError('Failed to get network information');
    }
  }

  /**
   * 获取账户余额
   */
  async getBalance(address?: string): Promise<string> {
    try {
      const targetAddress = address || this.wallet.address;
      const balance = await this.provider.getBalance(targetAddress);
      return ethers.formatEther(balance);
    } catch (error) {
      logger.error('Failed to get balance:', error);
      throw new BlockchainError('Failed to get account balance');
    }
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
      
      logger.debug('Contract call successful:', {
        contract: contractAddress,
        method,
        params,
        result: result.toString(),
      });

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
      
      const txOptions: any = {};
      if (value) {
        txOptions.value = ethers.parseEther(value);
      }

      const tx = await contract[method](...params, txOptions);
      
      logger.info('Contract write transaction sent:', {
        contract: contractAddress,
        method,
        params,
        txHash: tx.hash,
      });

      return tx;
    } catch (error) {
      logger.error('Contract write failed:', error);
      throw new BlockchainError(`Contract write failed: ${error instanceof Error ? error.message : String(error)}`);
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
}

// 创建单例实例
export const web3Service = new Web3Service();
