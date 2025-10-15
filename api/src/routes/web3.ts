import { FastifyInstance } from 'fastify';
import { web3Service } from '../services/web3Service';
import logger from '../utils/logger';

export async function web3Routes(fastify: FastifyInstance) {
  // 健康检查
  fastify.get('/web3/health', async (request, reply) => {
    return reply.send({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // 重置 nonce
  fastify.post('/web3/reset-nonce', async (request, reply) => {
    try {
      await web3Service.resetNonce();
      return reply.send({ success: true, message: 'Nonce reset successfully' });
    } catch (error) {
      logger.error('Failed to reset nonce:', error);
      return reply.status(500).send({ success: false, error: 'Failed to reset nonce' });
    }
  });
}
