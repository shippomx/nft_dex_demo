import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import logger, { loggerStream } from './utils/logger';
import { errorHandler } from './utils/errors';
import config from './config';

// 导入路由
import { deployRoutes } from './routes/deploy';
import { poolRoutes } from './routes/pool';
import { tradeRoutes } from './routes/trade';
import { web3Routes } from './routes/web3';

// 导入 Web3 服务
import { web3Service } from './services/web3Service';

// 创建 Fastify 实例
const fastify = Fastify({
  logger: {
    stream: loggerStream,
    level: config.logging.level,
  },
  disableRequestLogging: false,
});

// 注册插件
async function registerPlugins() {
  // CORS 支持
  await fastify.register(cors, {
    origin: config.api.corsOrigin === '*' ? true : config.api.corsOrigin,
    credentials: true,
  });

  // 安全头
  await fastify.register(helmet, {
    contentSecurityPolicy: false, // 禁用 CSP 以支持 Swagger UI
  });

  // Swagger 文档
  await fastify.register(swagger, {
    swagger: {
      info: {
        title: 'NFT DEX API',
        description: 'NFT DEX REST API 服务器，提供合约部署、流动性管理、交易等功能',
        version: '1.0.0',
        contact: {
          name: 'NFT DEX Team',
          email: 'team@nftdex.com',
        },
        license: {
          name: 'MIT',
          url: 'https://opensource.org/licenses/MIT',
        },
      },
      host: `${config.server.host}:${config.server.port}`,
      schemes: ['http', 'https'],
      consumes: ['application/json'],
      produces: ['application/json'],
      tags: [
        { name: 'deploy', description: '合约部署相关接口' },
        { name: 'pool', description: '流动性池管理相关接口' },
        { name: 'trade', description: '交易相关接口' },
      ],
      definitions: {
        Error: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            error: {
              type: 'object',
              properties: {
                message: { type: 'string', example: 'Error message' },
                code: { type: 'number', example: 400 },
                type: { type: 'string', example: 'ValidationError' },
              },
            },
          },
        },
        Success: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: true },
            message: { type: 'string', example: 'Success' },
            data: { type: 'object' },
          },
        },
      },
    },
  });

  // Swagger UI
  await fastify.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: false,
    },
    uiHooks: {
      onRequest: function (request, reply, next) {
        next();
      },
      preHandler: function (request, reply, next) {
        next();
      },
    },
    staticCSP: true,
    transformStaticCSP: (header) => header,
    transformSpecification: (swaggerObject, request, reply) => {
      return swaggerObject;
    },
    transformSpecificationClone: true,
  });
}

// 注册路由
async function registerRoutes() {
  // 注册部署路由
  await fastify.register(deployRoutes, { prefix: config.api.prefix });

  // 注册池子路由
  await fastify.register(poolRoutes, { prefix: config.api.prefix });

  // 注册交易路由
  await fastify.register(tradeRoutes, { prefix: config.api.prefix });

  // 注册 Web3 路由
  await fastify.register(web3Routes, { prefix: config.api.prefix });

  // 健康检查端点
  fastify.get('/health', async (request, reply) => {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: '1.0.0',
    };
  });

  // 根路径
  fastify.get('/', async (request, reply) => {
    return {
      message: 'NFT DEX API Server',
      version: '1.0.0',
      documentation: '/docs',
      health: '/health',
      api: config.api.prefix,
    };
  });
}

// 错误处理
fastify.setErrorHandler(errorHandler);

// 启动服务器
async function start() {
  try {
    // 检查 RPC 端点连接
    logger.info('='.repeat(60));
    logger.info('🔍 Performing startup checks...');
    logger.info('='.repeat(60));
    
    const rpcConnected = await web3Service.checkRpcConnection();
    
    if (!rpcConnected) {
      logger.error('='.repeat(60));
      logger.error('❌ FATAL ERROR: Cannot connect to blockchain node!');
      logger.error('❌ RPC URL: ' + config.blockchain.rpcUrl);
      logger.error('❌ Server startup aborted.');
      logger.error('❌ Please check:');
      logger.error('❌   1. Is the blockchain node running?');
      logger.error('❌      Command: anvil');
      logger.error('❌   2. Is the RPC_URL correct in your .env file?');
      logger.error('❌      Current: ' + config.blockchain.rpcUrl);
      logger.error('❌   3. Is there a firewall blocking the connection?');
      logger.error('='.repeat(60));
      process.exit(1);
    }

    logger.info('');
    logger.info('Starting HTTP server...');
    
    // 注册插件
    await registerPlugins();

    // 注册路由
    await registerRoutes();

    // 启动服务器
    await fastify.listen({
      port: config.server.port,
      host: config.server.host,
    });

    logger.info('');
    logger.info('='.repeat(60));
    logger.info('🚀 NFT DEX API Server started successfully!');
    logger.info('='.repeat(60));
    logger.info('📍 Server Information:');
    logger.info(`   - Port: ${config.server.port}`);
    logger.info(`   - Host: ${config.server.host}`);
    logger.info(`   - Environment: ${config.server.nodeEnv}`);
    logger.info(`   - API Prefix: ${config.api.prefix}`);
    logger.info('');
    logger.info('📚 Available Endpoints:');
    logger.info(`   - API Documentation: http://${config.server.host === '0.0.0.0' ? 'localhost' : config.server.host}:${config.server.port}/docs`);
    logger.info(`   - Health Check: http://${config.server.host === '0.0.0.0' ? 'localhost' : config.server.host}:${config.server.port}/health`);
    logger.info(`   - API Root: http://${config.server.host === '0.0.0.0' ? 'localhost' : config.server.host}:${config.server.port}${config.api.prefix}`);
    logger.info('');
    logger.info('⛓️  Blockchain Configuration:');
    logger.info(`   - RPC URL: ${config.blockchain.rpcUrl}`);
    logger.info(`   - Chain ID: ${config.blockchain.chainId}`);
    logger.info(`   - RPC Status: ✅ Connected`);
    logger.info('='.repeat(60));

    // 优雅关闭处理
    process.on('SIGINT', async () => {
      logger.info('Received SIGINT, shutting down gracefully...');
      await fastify.close();
      process.exit(0);
    });

    process.on('SIGTERM', async () => {
      logger.info('Received SIGTERM, shutting down gracefully...');
      await fastify.close();
      process.exit(0);
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// 启动应用
if (require.main === module) {
  start();
}

export default fastify;
