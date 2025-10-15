import * as fs from 'fs';
import * as path from 'path';
import logger from '../../utils/logger';
import { ContractError } from '../../utils/errors';

/**
 * Foundry 编译输出文件接口
 */
export interface FoundryArtifact {
  abi: any[];
  bytecode: string;
  deployedBytecode: string;
  linkReferences: any;
  deployedLinkReferences: any;
  sourceName: string;
  contractName: string;
  sourceId: string;
  ast: any;
  compiler: {
    name: string;
    version: string;
  };
  networks: any;
  schemaVersion: string;
  updatedAt: string;
  devdoc: any;
  userdoc: any;
  metadata: string;
  ir: string;
  irOptimized: string;
  storageLayout: any;
  generatedSources: any[];
  deployedGeneratedSources: any[];
  immutableReferences: any;
  evm: {
    assembly: string;
    legacyAssembly: any;
    bytecode: {
      functionDebugData: any;
      generatedSources: any[];
      linkReferences: any;
      object: string;
      opcodes: string;
      sourceMap: string;
    };
    deployedBytecode: {
      functionDebugData: any;
      generatedSources: any[];
      immutableReferences: any;
      linkReferences: any;
      object: string;
      opcodes: string;
      sourceMap: string;
    };
    methodIdentifiers: any;
    gasEstimates: any;
  };
}

/**
 * 合约字节码和 ABI 信息
 */
export interface ContractInfo {
  abi: any[];
  bytecode: string;
  contractName: string;
  sourceName: string;
}

/**
 * 字节码加载器服务
 * 负责从 Foundry 编译输出中加载合约字节码和 ABI
 */
export class BytecodeLoader {
  private artifactsPath: string;
  private cache: Map<string, ContractInfo> = new Map();

  constructor(artifactsPath?: string) {
    // 默认使用项目根目录的 out 文件夹
    this.artifactsPath = artifactsPath || path.join(process.cwd(), '..', 'out');
    
    logger.info('BytecodeLoader initialized', {
      artifactsPath: this.artifactsPath,
    });
  }

  /**
   * 加载合约信息
   * @param contractName 合约名称
   * @param sourceName 源文件名称（可选）
   * @returns 合约信息
   */
  async loadContract(contractName: string, sourceName?: string): Promise<ContractInfo> {
    const cacheKey = `${contractName}${sourceName ? `_${sourceName}` : ''}`;
    
    // 检查缓存
    if (this.cache.has(cacheKey)) {
      logger.debug('Contract loaded from cache', { contractName, sourceName });
      return this.cache.get(cacheKey)!;
    }

    try {
      const artifact = await this.loadArtifact(contractName, sourceName);
      
      const contractInfo: ContractInfo = {
        abi: artifact.abi,
        bytecode: artifact.bytecode || artifact.evm?.bytecode?.object || '',
        contractName: artifact.contractName || contractName,
        sourceName: artifact.sourceName || 'unknown',
      };

      // 缓存结果
      this.cache.set(cacheKey, contractInfo);
      
      logger.info('Contract loaded successfully', {
        contractName: artifact.contractName,
        sourceName: artifact.sourceName,
        bytecodeLength: artifact.bytecode.length,
        abiLength: artifact.abi.length,
      });

      return contractInfo;
    } catch (error) {
      logger.error('Failed to load contract:', error);
      throw new ContractError(`Failed to load contract ${contractName}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 加载 Foundry 编译输出文件
   * @param contractName 合约名称
   * @param sourceName 源文件名称（可选）
   * @returns Foundry 编译输出
   */
  private async loadArtifact(contractName: string, sourceName?: string): Promise<FoundryArtifact> {
    const possiblePaths = this.getPossiblePaths(contractName, sourceName);
    
    for (const filePath of possiblePaths) {
      try {
        if (fs.existsSync(filePath)) {
          const content = fs.readFileSync(filePath, 'utf8');
          const artifact: FoundryArtifact = JSON.parse(content);
          
          // 验证必要的字段
          if (!artifact.abi || !artifact.bytecode) {
            throw new Error(`Invalid artifact: missing abi or bytecode`);
          }
          
          logger.debug('Artifact loaded from file', {
            filePath,
            contractName: artifact.contractName,
            sourceName: artifact.sourceName,
          });
          
          return artifact;
        }
      } catch (error) {
        logger.warn('Failed to load artifact from path:', { filePath, error: error instanceof Error ? error.message : String(error) });
        continue;
      }
    }
    
    throw new Error(`Contract artifact not found for ${contractName}${sourceName ? ` in ${sourceName}` : ''}`);
  }

  /**
   * 获取可能的文件路径
   * @param contractName 合约名称
   * @param sourceName 源文件名称（可选）
   * @returns 可能的文件路径数组
   */
  private getPossiblePaths(contractName: string, sourceName?: string): string[] {
    const paths: string[] = [];
    
    if (sourceName) {
      // 如果指定了源文件名称
      paths.push(
        path.join(this.artifactsPath, `${sourceName}.sol`, `${contractName}.json`),
        path.join(this.artifactsPath, `${sourceName}`, `${contractName}.json`)
      );
    } else {
      // 尝试常见的源文件名称
      const commonSourceNames = [
        contractName,
        'src',
        'contracts',
        'StandardNFT',
        'Pair',
        'PairFactory',
        'LPToken'
      ];
      
      for (const srcName of commonSourceNames) {
        paths.push(
          path.join(this.artifactsPath, `${srcName}.sol`, `${contractName}.json`),
          path.join(this.artifactsPath, `${srcName}`, `${contractName}.json`)
        );
      }
    }
    
    return paths;
  }

  /**
   * 列出所有可用的合约
   * @returns 合约名称列表
   */
  async listAvailableContracts(): Promise<string[]> {
    try {
      const contracts: string[] = [];
      
      if (!fs.existsSync(this.artifactsPath)) {
        logger.warn('Artifacts path does not exist', { artifactsPath: this.artifactsPath });
        return contracts;
      }
      
      const entries = fs.readdirSync(this.artifactsPath, { withFileTypes: true });
      
      for (const entry of entries) {
        if (entry.isDirectory()) {
          const contractDir = path.join(this.artifactsPath, entry.name);
          const contractFiles = fs.readdirSync(contractDir);
          
          for (const file of contractFiles) {
            if (file.endsWith('.json')) {
              const contractName = path.basename(file, '.json');
              contracts.push(contractName);
            }
          }
        }
      }
      
      logger.info('Available contracts listed', { count: contracts.length, contracts });
      return contracts;
    } catch (error) {
      logger.error('Failed to list available contracts:', error);
      return [];
    }
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.cache.clear();
    logger.info('BytecodeLoader cache cleared');
  }

  /**
   * 获取缓存状态
   */
  getCacheStatus(): { size: number; keys: string[] } {
    return {
      size: this.cache.size,
      keys: Array.from(this.cache.keys()),
    };
  }
}

// 创建单例实例
export const bytecodeLoader = new BytecodeLoader();
