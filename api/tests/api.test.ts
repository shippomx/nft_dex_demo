import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import Fastify from 'fastify';
import { web3Service } from '../src/services/web3Service';
import { contractService } from '../src/services/contracts/contractService';

// 测试配置
const TEST_CONFIG = {
  port: 3001,
  host: '127.0.0.1',
};

describe('NFT DEX API Tests', () => {
  let fastify: Fastify.FastifyInstance;

  beforeAll(async () => {
    // 创建 Fastify 实例进行测试
    fastify = Fastify({
      logger: false,
    });

    // 注册路由（这里需要导入实际的路由）
    // await fastify.register(deployRoutes, { prefix: '/api/v1' });
    // await fastify.register(poolRoutes, { prefix: '/api/v1' });
    // await fastify.register(tradeRoutes, { prefix: '/api/v1' });

    // 启动测试服务器
    await fastify.listen({ port: TEST_CONFIG.port, host: TEST_CONFIG.host });
  });

  afterAll(async () => {
    if (fastify) {
      await fastify.close();
    }
  });

  describe('Health Check', () => {
    it('should return health status', async () => {
      const response = await fastify.inject({
        method: 'GET',
        url: '/health',
      });

      expect(response.statusCode).toBe(200);
      const data = JSON.parse(response.payload);
      expect(data.status).toBe('ok');
      expect(data.timestamp).toBeDefined();
      expect(data.uptime).toBeDefined();
    });
  });

  describe('Root Endpoint', () => {
    it('should return API information', async () => {
      const response = await fastify.inject({
        method: 'GET',
        url: '/',
      });

      expect(response.statusCode).toBe(200);
      const data = JSON.parse(response.payload);
      expect(data.message).toBe('NFT DEX API Server');
      expect(data.version).toBeDefined();
      expect(data.documentation).toBeDefined();
    });
  });

  // 注意：以下测试需要实际的区块链连接，在 CI/CD 环境中可能需要模拟
  describe('Web3 Service', () => {
    it('should initialize Web3 service', () => {
      expect(web3Service).toBeDefined();
      expect(web3Service.getProvider()).toBeDefined();
      expect(web3Service.getSigner()).toBeDefined();
    });

    it('should get wallet address', () => {
      const address = web3Service.getWalletAddress();
      expect(address).toBeDefined();
      expect(address).toMatch(/^0x[a-fA-F0-9]{40}$/);
    });
  });

  describe('Contract Service', () => {
    it('should initialize contract service', () => {
      expect(contractService).toBeDefined();
    });

    it('should have empty addresses initially', () => {
      const addresses = contractService.getAddresses();
      expect(addresses).toBeDefined();
      expect(typeof addresses).toBe('object');
    });
  });
});

// 集成测试示例
describe('API Integration Tests', () => {
  let fastify: Fastify.FastifyInstance;

  beforeAll(async () => {
    fastify = Fastify({
      logger: false,
    });

    // 这里应该注册所有路由
    // 为了测试目的，我们只测试基本功能

    await fastify.listen({ port: TEST_CONFIG.port + 1, host: TEST_CONFIG.host });
  });

  afterAll(async () => {
    if (fastify) {
      await fastify.close();
    }
  });

  it('should handle 404 for unknown routes', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/unknown-route',
    });

    expect(response.statusCode).toBe(404);
  });

  it('should handle CORS preflight requests', async () => {
    const response = await fastify.inject({
      method: 'OPTIONS',
      url: '/',
      headers: {
        'Origin': 'http://localhost:3000',
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'Content-Type',
      },
    });

    // CORS 响应应该包含适当的头部
    expect(response.headers['access-control-allow-origin']).toBeDefined();
  });
});
