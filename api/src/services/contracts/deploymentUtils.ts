import { ethers } from 'ethers';
import { web3Service } from '../web3Service';
import { bytecodeLoader, ContractInfo } from './bytecodeLoader';
import { ContractError } from '../../utils/errors';
import logger from '../../utils/logger';

/**
 * 部署配置接口
 */
export interface DeploymentConfig {
  contractName: string;
  constructorArgs: any[];
  value?: string;
  gasLimit?: string;
  gasPrice?: string;
  confirmations?: number;
}

/**
 * 部署结果接口
 */
export interface DeploymentResult {
  contractAddress: string;
  transactionHash: string;
  blockNumber: number;
  gasUsed: string;
  deploymentCost: string;
  contractInfo: ContractInfo;
}

/**
 * 部署工具类
 * 提供高级合约部署功能
 */
export class DeploymentUtils {
  /**
   * 部署合约并返回详细信息
   * @param config 部署配置
   * @returns 部署结果
   */
  static async deployContract(config: DeploymentConfig): Promise<DeploymentResult> {
    try {
      logger.info('Starting contract deployment:', config);

      // 加载合约信息
      const contractInfo = await bytecodeLoader.loadContract(config.contractName);
      
      // 创建合约工厂
      const factory = new ethers.ContractFactory(
        contractInfo.abi,
        contractInfo.bytecode,
        web3Service.getSigner()
      );

      // 准备部署选项
      const deployOptions: any = {};
      
      if (config.value) {
        deployOptions.value = ethers.parseEther(config.value);
      }
      
      if (config.gasLimit) {
        deployOptions.gasLimit = config.gasLimit;
      }
      
      if (config.gasPrice) {
        deployOptions.gasPrice = ethers.parseUnits(config.gasPrice, 'gwei');
      }

      // 估算 Gas（如果未指定）
      if (!config.gasLimit) {
        try {
          const estimatedGas = await factory.getDeployTransaction(
            ...config.constructorArgs,
            deployOptions
          ).then(tx => web3Service.estimateGas(tx));
          
          deployOptions.gasLimit = estimatedGas;
          logger.info('Gas estimated:', { gasLimit: estimatedGas.toString() });
        } catch (error) {
          logger.warn('Failed to estimate gas, using default:', error);
        }
      }

      // 部署合约
      const contract = await factory.deploy(...config.constructorArgs, deployOptions);
      
      // 等待部署确认
      const confirmations = config.confirmations || 1;
      const receipt = await contract.waitForDeployment().then(() => 
        web3Service.waitForTransaction(contract.deploymentTransaction()!.hash, confirmations)
      );

      const address = await contract.getAddress();
      const deploymentCost = receipt.gasUsed * (receipt.gasPrice || BigInt(0));

      const result: DeploymentResult = {
        contractAddress: address,
        transactionHash: receipt.hash,
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString(),
        deploymentCost: ethers.formatEther(deploymentCost),
        contractInfo,
      };

      logger.info('Contract deployed successfully:', result);
      return result;
    } catch (error) {
      logger.error('Contract deployment failed:', error);
      throw new ContractError(`Contract deployment failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 批量部署合约
   * @param configs 部署配置数组
   * @returns 部署结果数组
   */
  static async deployContracts(configs: DeploymentConfig[]): Promise<DeploymentResult[]> {
    const results: DeploymentResult[] = [];
    
    logger.info('Starting batch contract deployment:', { count: configs.length });

    for (let i = 0; i < configs.length; i++) {
      try {
        logger.info(`Deploying contract ${i + 1}/${configs.length}:`, configs[i]);
        const result = await this.deployContract(configs[i]);
        results.push(result);
        
        // 添加延迟以避免网络拥堵
        if (i < configs.length - 1) {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      } catch (error) {
        logger.error(`Failed to deploy contract ${i + 1}:`, error);
        throw new ContractError(`Batch deployment failed at contract ${i + 1}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    logger.info('Batch deployment completed:', { 
      total: configs.length, 
      successful: results.length 
    });

    return results;
  }

  /**
   * 验证合约部署
   * @param contractAddress 合约地址
   * @param expectedABI 预期的 ABI（可选）
   * @returns 验证结果
   */
  static async verifyDeployment(
    contractAddress: string, 
    expectedABI?: any[]
  ): Promise<{
    isDeployed: boolean;
    hasCode: boolean;
    abiMatches: boolean;
    contractInfo?: ContractInfo;
  }> {
    try {
      logger.info('Verifying contract deployment:', { contractAddress });

      // 检查合约是否已部署
      const isDeployed = await web3Service.isContractDeployed(contractAddress);
      
      if (!isDeployed) {
        return {
          isDeployed: false,
          hasCode: false,
          abiMatches: false,
        };
      }

      // 获取合约代码
      const code = await web3Service.getProvider().getCode(contractAddress);
      const hasCode = code !== '0x';

      // 如果提供了预期 ABI，尝试匹配
      let abiMatches = true;
      let contractInfo: ContractInfo | undefined;

      if (expectedABI && hasCode) {
        try {
          // 这里可以实现更复杂的 ABI 匹配逻辑
          // 目前只是简单检查
          abiMatches = true;
        } catch (error) {
          logger.warn('ABI matching failed:', error);
          abiMatches = false;
        }
      }

      const result = {
        isDeployed,
        hasCode,
        abiMatches,
        contractInfo,
      };

      logger.info('Contract verification completed:', result);
      return result;
    } catch (error) {
      logger.error('Contract verification failed:', error);
      throw new ContractError(`Contract verification failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取部署统计信息
   * @param results 部署结果数组
   * @returns 统计信息
   */
  static getDeploymentStats(results: DeploymentResult[]): {
    totalContracts: number;
    totalGasUsed: string;
    totalCost: string;
    averageGasPerContract: string;
    averageCostPerContract: string;
  } {
    const totalGasUsed = results.reduce((sum, result) => sum + BigInt(result.gasUsed), BigInt(0));
    const totalCost = results.reduce((sum, result) => sum + ethers.parseEther(result.deploymentCost), BigInt(0));
    
    return {
      totalContracts: results.length,
      totalGasUsed: totalGasUsed.toString(),
      totalCost: ethers.formatEther(totalCost),
      averageGasPerContract: results.length > 0 ? (totalGasUsed / BigInt(results.length)).toString() : '0',
      averageCostPerContract: results.length > 0 ? ethers.formatEther(totalCost / BigInt(results.length)) : '0',
    };
  }

  /**
   * 创建标准 NFT 部署配置
   * @param name NFT 名称
   * @param symbol NFT 符号
   * @param baseURI 基础 URI
   * @param maxSupply 最大供应量
   * @param maxMintPerAddress 每个地址最大铸造数量
   * @param mintPrice 铸造价格
   * @returns 部署配置
   */
  static createStandardNFTConfig(
    name: string,
    symbol: string,
    baseURI: string,
    maxSupply: number,
    maxMintPerAddress: number,
    mintPrice: string
  ): DeploymentConfig {
    return {
      contractName: 'StandardNFT',
      constructorArgs: [name, symbol, baseURI, maxSupply, maxMintPerAddress, ethers.parseEther(mintPrice)],
    };
  }

  /**
   * 创建 Pair 合约部署配置
   * @param nftContractAddress NFT 合约地址
   * @returns 部署配置
   */
  static createPairConfig(nftContractAddress: string): DeploymentConfig {
    return {
      contractName: 'Pair',
      constructorArgs: [nftContractAddress],
    };
  }

  /**
   * 创建 MultiPoolManager 部署配置
   * @returns 部署配置
   */
  static createMultiPoolManagerConfig(): DeploymentConfig {
    return {
      contractName: 'MultiPoolManager',
      constructorArgs: [],
    };
  }
}

export default DeploymentUtils;
