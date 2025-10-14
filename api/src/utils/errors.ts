import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import logger from './logger';

// 自定义错误类
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly isOperational: boolean;

  constructor(message: string, statusCode: number = 500, isOperational: boolean = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;

    Error.captureStackTrace(this, this.constructor);
  }
}

// 区块链相关错误
export class BlockchainError extends AppError {
  constructor(message: string, statusCode: number = 500) {
    super(message, statusCode);
  }
}

// 合约相关错误
export class ContractError extends AppError {
  constructor(message: string, statusCode: number = 400) {
    super(message, statusCode);
  }
}

// 验证错误
export class ValidationError extends AppError {
  constructor(message: string, statusCode: number = 400) {
    super(message, statusCode);
  }
}

// 错误处理函数
export const errorHandler = (
  error: FastifyError | AppError,
  request: FastifyRequest,
  reply: FastifyReply
) => {
  // 记录错误
  logger.error('Error occurred:', {
    error: error.message,
    stack: error.stack,
    url: request.url,
    method: request.method,
    ip: request.ip,
  });

  // 如果是自定义错误
  if (error instanceof AppError) {
    return reply.status(error.statusCode).send({
      success: false,
      error: {
        message: error.message,
        code: error.statusCode,
        type: error.constructor.name,
      },
    });
  }

  // 如果是 Fastify 验证错误
  if (error.validation) {
    return reply.status(400).send({
      success: false,
      error: {
        message: 'Validation error',
        code: 400,
        type: 'ValidationError',
        details: error.validation,
      },
    });
  }

  // 默认错误处理
  const statusCode = error.statusCode || 500;
  const message = statusCode === 500 ? 'Internal server error' : error.message;

  return reply.status(statusCode).send({
    success: false,
    error: {
      message,
      code: statusCode,
      type: 'InternalError',
    },
  });
};

// 成功响应格式
export const successResponse = (data: any, message: string = 'Success') => ({
  success: true,
  message,
  data,
});

// 分页响应格式
export const paginatedResponse = (
  data: any[],
  total: number,
  page: number,
  limit: number,
  message: string = 'Success'
) => ({
  success: true,
  message,
  data: {
    items: data,
    pagination: {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    },
  },
});
