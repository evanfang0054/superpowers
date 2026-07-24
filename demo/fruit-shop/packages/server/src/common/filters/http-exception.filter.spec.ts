import { HttpException, HttpStatus, ServiceUnavailableException } from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import { HttpExceptionFilter } from './http-exception.filter';

describe('HttpExceptionFilter', () => {
  let filter: HttpExceptionFilter;
  let logger: any;
  let response: any;
  let host: any;

  beforeEach(() => {
    logger = { warn: jest.fn(), error: jest.fn() };
    filter = new HttpExceptionFilter(logger);
    response = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    host = {
      switchToHttp: () => ({
        getRequest: () => ({ method: 'POST', url: '/api/x' }),
        getResponse: () => response,
      }),
    } as any;
  });

  it('should pass through business code', () => {
    filter.catch(
      new HttpException({ code: 40001, message: 'phone exists' }, HttpStatus.CONFLICT),
      host,
    );
    expect(response.json).toHaveBeenCalledWith({ code: 40001, message: 'phone exists' });
    expect(response.status).toHaveBeenCalledWith(HttpStatus.OK);
  });

  it('should join class-validator array messages', () => {
    filter.catch(
      new HttpException(
        { message: ['phone invalid', 'password short'], error: 'Bad Request', statusCode: 400 },
        HttpStatus.BAD_REQUEST,
      ),
      host,
    );
    const args = response.json.mock.calls[0][0];
    expect(args.code).toBe(400);
    expect(args.message).toContain('; ');
  });

  it('should use string response directly', () => {
    filter.catch(new HttpException('plain msg', HttpStatus.BAD_REQUEST), host);
    expect(response.json).toHaveBeenCalledWith({ code: 400, message: 'plain msg' });
  });

  it('should fallback to status code for plain HttpException', () => {
    filter.catch(new HttpException('not found', HttpStatus.NOT_FOUND), host);
    expect(response.json).toHaveBeenCalledWith({ code: 404, message: 'not found' });
  });

  it('should return 429 for ThrottlerException', () => {
    filter.catch(new ThrottlerException(), host);
    expect(response.status).toHaveBeenCalledWith(HttpStatus.TOO_MANY_REQUESTS);
    const args = response.json.mock.calls[0][0];
    expect(args.code).toBe(429);
    expect(args.message).toBe('Too Many Requests');
  });

  it('should pass through terminus body on ServiceUnavailableException', () => {
    const terminusBody = { status: 'error', details: { db: { status: 'down' } } };
    filter.catch(new ServiceUnavailableException({ response: terminusBody }), host);
    expect(response.status).toHaveBeenCalledWith(HttpStatus.SERVICE_UNAVAILABLE);
    expect(response.json).toHaveBeenCalledWith(terminusBody);
  });

  it('should log error and return 500 on unknown exception', () => {
    filter.catch(new Error('boom'), host);
    expect(logger.error).toHaveBeenCalled();
    expect(response.json).toHaveBeenCalledWith({ code: 500, message: '服务器内部错误' });
  });
});
