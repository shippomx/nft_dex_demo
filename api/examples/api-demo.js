#!/usr/bin/env node

/**
 * NFT DEX API 演示脚本
 * 展示如何使用 API 进行合约部署、池子管理和交易
 */

const axios = require('axios');

// API 配置
const API_BASE_URL = 'http://localhost:3000/api/v1';

// 创建 axios 实例
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 颜色输出
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSection(title) {
  log(`\n${'='.repeat(50)}`, 'cyan');
  log(`  ${title}`, 'bright');
  log(`${'='.repeat(50)}`, 'cyan');
}

function logStep(step, message) {
  log(`\n${step}. ${message}`, 'yellow');
}

function logSuccess(message) {
  log(`✅ ${message}`, 'green');
}

function logError(message) {
  log(`❌ ${message}`, 'red');
}

function logInfo(message) {
  log(`ℹ️  ${message}`, 'blue');
}

// 等待用户输入
function waitForInput(message) {
  return new Promise((resolve) => {
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    
    rl.question(message, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

// 检查服务器状态
async function checkServerStatus() {
  try {
    const response = await api.get('/health');
    logSuccess('服务器运行正常');
    logInfo(`状态: ${response.data.status}`);
    logInfo(`运行时间: ${Math.round(response.data.uptime)} 秒`);
    return true;
  } catch (error) {
    logError('无法连接到服务器');
    logError(`请确保服务器正在运行: npm run dev`);
    return false;
  }
}

// 部署 NFT 合约
async function deployNFTContract() {
  logStep(1, '部署 NFT 合约');
  
  const nftConfig = {
    name: 'Demo NFT Collection',
    symbol: 'DEMO',
    baseURI: 'https://api.example.com/metadata/',
    maxSupply: 1000,
    maxMintPerAddress: 50,
    mintPrice: '0.01',
  };

  try {
    logInfo('发送部署请求...');
    const response = await api.post('/deploy/nft', nftConfig);
    
    if (response.data.success) {
      logSuccess('NFT 合约部署成功');
      logInfo(`合约地址: ${response.data.data.contractAddress}`);
      return response.data.data.contractAddress;
    } else {
      logError('NFT 合约部署失败');
      return null;
    }
  } catch (error) {
    logError(`NFT 合约部署失败: ${error.response?.data?.error?.message || error.message}`);
    return null;
  }
}

// 部署 Pair 合约
async function deployPairContract(nftContractAddress) {
  logStep(2, '部署 Pair 合约');
  
  try {
    logInfo('发送部署请求...');
    const response = await api.post('/deploy/pair', {
      nftContractAddress,
    });
    
    if (response.data.success) {
      logSuccess('Pair 合约部署成功');
      logInfo(`合约地址: ${response.data.data.contractAddress}`);
      return response.data.data.contractAddress;
    } else {
      logError('Pair 合约部署失败');
      return null;
    }
  } catch (error) {
    logError(`Pair 合约部署失败: ${error.response?.data?.error?.message || error.message}`);
    return null;
  }
}

// 添加初始流动性
async function addInitialLiquidity() {
  logStep(3, '添加初始流动性');
  
  const liquidityConfig = {
    nftTokenIds: [1, 2, 3, 4, 5], // 假设这些 NFT 已经存在
    ethAmount: '1.0',
  };

  try {
    logInfo('发送添加流动性请求...');
    const response = await api.post('/pool/add-liquidity', liquidityConfig);
    
    if (response.data.success) {
      logSuccess('初始流动性添加成功');
      logInfo(`交易哈希: ${response.data.data.txHash}`);
      return true;
    } else {
      logError('添加流动性失败');
      return false;
    }
  } catch (error) {
    logError(`添加流动性失败: ${error.response?.data?.error?.message || error.message}`);
    return false;
  }
}

// 查询价格信息
async function queryPrices() {
  logStep(4, '查询价格信息');
  
  try {
    // 获取当前价格
    const currentPriceResponse = await api.get('/trade/price?type=current');
    if (currentPriceResponse.data.success) {
      logInfo(`当前价格: ${currentPriceResponse.data.data.current} ETH`);
    }

    // 获取卖出价格
    const sellPriceResponse = await api.get('/trade/price?type=sell');
    if (sellPriceResponse.data.success) {
      logInfo(`卖出价格: ${sellPriceResponse.data.data.sell} ETH`);
    }

    // 获取买入报价
    const buyQuoteResponse = await api.get('/trade/quote');
    if (buyQuoteResponse.data.success) {
      const quote = buyQuoteResponse.data.data;
      logInfo(`买入总成本: ${quote.totalCost} ETH`);
      logInfo(`手续费: ${quote.fee} ETH`);
    }

    // 获取池子储备量
    const reservesResponse = await api.get('/trade/reserves');
    if (reservesResponse.data.success) {
      const reserves = reservesResponse.data.data;
      logInfo(`ETH 储备: ${reserves.ethReserve} ETH`);
      logInfo(`NFT 储备: ${reserves.nftReserve} 个`);
    }

    return true;
  } catch (error) {
    logError(`查询价格失败: ${error.response?.data?.error?.message || error.message}`);
    return false;
  }
}

// 模拟交易
async function simulateTrading() {
  logStep(5, '模拟交易');
  
  try {
    // 买入 NFT
    logInfo('尝试买入 NFT...');
    const buyResponse = await api.post('/trade/buy', {
      maxPrice: '0.1',
    });
    
    if (buyResponse.data.success) {
      logSuccess('NFT 买入成功');
      logInfo(`交易哈希: ${buyResponse.data.data.txHash}`);
    } else {
      logError('NFT 买入失败');
    }

    // 卖出 NFT（假设有 tokenId 1）
    logInfo('尝试卖出 NFT...');
    const sellResponse = await api.post('/trade/sell', {
      tokenId: 1,
      minPrice: '0.05',
    });
    
    if (sellResponse.data.success) {
      logSuccess('NFT 卖出成功');
      logInfo(`交易哈希: ${sellResponse.data.data.txHash}`);
    } else {
      logError('NFT 卖出失败');
    }

    return true;
  } catch (error) {
    logError(`交易失败: ${error.response?.data?.error?.message || error.message}`);
    return false;
  }
}

// 查询交易历史
async function queryTradeHistory() {
  logStep(6, '查询交易历史');
  
  try {
    const response = await api.get('/trade/history?limit=10');
    
    if (response.data.success) {
      const trades = response.data.data.items;
      logSuccess(`查询到 ${trades.length} 条交易记录`);
      
      trades.forEach((trade, index) => {
        const type = trade.isBuy ? '买入' : '卖出';
        const time = new Date(trade.timestamp * 1000).toLocaleString();
        logInfo(`${index + 1}. ${type} - 价格: ${trade.price} ETH - 时间: ${time}`);
      });
    } else {
      logError('查询交易历史失败');
    }

    return true;
  } catch (error) {
    logError(`查询交易历史失败: ${error.response?.data?.error?.message || error.message}`);
    return false;
  }
}

// 主函数
async function main() {
  logSection('NFT DEX API 演示脚本');
  log('这个脚本将演示 NFT DEX API 的主要功能', 'bright');
  
  // 检查服务器状态
  const isServerRunning = await checkServerStatus();
  if (!isServerRunning) {
    process.exit(1);
  }

  // 询问是否继续
  const continueDemo = await waitForInput('\n是否继续演示？(y/N): ');
  if (continueDemo.toLowerCase() !== 'y' && continueDemo.toLowerCase() !== 'yes') {
    log('演示已取消', 'yellow');
    process.exit(0);
  }

  try {
    // 1. 部署 NFT 合约
    const nftContractAddress = await deployNFTContract();
    if (!nftContractAddress) {
      logError('无法继续，NFT 合约部署失败');
      process.exit(1);
    }

    // 等待用户确认
    await waitForInput('\n按 Enter 继续到下一步...');

    // 2. 部署 Pair 合约
    const pairContractAddress = await deployPairContract(nftContractAddress);
    if (!pairContractAddress) {
      logError('无法继续，Pair 合约部署失败');
      process.exit(1);
    }

    await waitForInput('\n按 Enter 继续到下一步...');

    // 3. 添加初始流动性
    const liquidityAdded = await addInitialLiquidity();
    if (!liquidityAdded) {
      logError('无法继续，添加流动性失败');
      process.exit(1);
    }

    await waitForInput('\n按 Enter 继续到下一步...');

    // 4. 查询价格信息
    await queryPrices();

    await waitForInput('\n按 Enter 继续到下一步...');

    // 5. 模拟交易
    await simulateTrading();

    await waitForInput('\n按 Enter 继续到下一步...');

    // 6. 查询交易历史
    await queryTradeHistory();

    logSection('演示完成');
    logSuccess('所有功能演示完成！');
    logInfo('您可以访问 http://localhost:3000/docs 查看完整的 API 文档');
    logInfo('或者使用 Postman、curl 等工具测试 API 接口');

  } catch (error) {
    logError(`演示过程中发生错误: ${error.message}`);
    process.exit(1);
  }
}

// 运行主函数
if (require.main === module) {
  main().catch((error) => {
    logError(`未处理的错误: ${error.message}`);
    process.exit(1);
  });
}

module.exports = {
  checkServerStatus,
  deployNFTContract,
  deployPairContract,
  addInitialLiquidity,
  queryPrices,
  simulateTrading,
  queryTradeHistory,
};
