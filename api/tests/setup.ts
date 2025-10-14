// Jest 测试设置文件

// 设置测试环境变量
process.env.NODE_ENV = 'test';
process.env.PORT = '3001';
process.env.HOST = '127.0.0.1';
process.env.RPC_URL = 'http://localhost:8545';
process.env.CHAIN_ID = '31337';
process.env.PRIVATE_KEY = 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
process.env.LOG_LEVEL = 'error'; // 测试时减少日志输出
process.env.API_PREFIX = '/api/v1';
process.env.CORS_ORIGIN = '*';

// 全局测试超时设置
jest.setTimeout(10000);

// 测试前清理
beforeEach(() => {
  // 清理控制台输出
  jest.clearAllMocks();
});

// 测试后清理
afterEach(() => {
  // 清理任何全局状态
});

// 全局错误处理
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});
