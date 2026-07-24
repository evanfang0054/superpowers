import { NotFoundException, BadRequestException } from '@nestjs/common';
import { OrderStatus } from 'shared';
import { OrderService } from './order.service';

describe('OrderService', () => {
  let service: OrderService;
  let orderRepo: any;
  let orderItemRepo: any;
  let shippingRepo: any;
  let refundRepo: any;
  let addressRepo: any;
  let checkoutService: any;
  let lifecycleService: any;
  let dataSource: any;
  let queryRunner: any;
  let logger: any;

  beforeEach(() => {
    const execute = jest.fn();
    const deleteQb = {
      delete: jest.fn().mockReturnThis(),
      from: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute,
    };
    const managerQuery = jest.fn().mockResolvedValue([]);
    queryRunner = {
      connect: jest.fn(),
      startTransaction: jest.fn(),
      manager: {
        create: jest.fn((_, x) => x),
        save: jest.fn(),
        createQueryBuilder: jest.fn(() => deleteQb),
        query: managerQuery,
        find: jest.fn(),
      },
      commitTransaction: jest.fn(),
      rollbackTransaction: jest.fn(),
      release: jest.fn(),
    };
    dataSource = { createQueryRunner: jest.fn(() => queryRunner) };
    orderRepo = { createQueryBuilder: jest.fn(), findOne: jest.fn(), save: jest.fn() };
    orderItemRepo = { find: jest.fn() };
    shippingRepo = { findOne: jest.fn() };
    refundRepo = {};
    addressRepo = { findOne: jest.fn() };
    checkoutService = { create: jest.fn() };
    lifecycleService = {
      cancel: jest.fn(),
      pay: jest.fn(),
      ship: jest.fn(),
      confirm: jest.fn(),
      requestRefund: jest.fn(),
    };
    logger = { setContext: jest.fn(), info: jest.fn() };
    service = new OrderService(
      orderRepo,
      orderItemRepo,
      shippingRepo,
      refundRepo,
      addressRepo,
      checkoutService,
      lifecycleService,
      dataSource,
      logger,
    );
  });

  describe('create', () => {
    it('should throw BadRequest when cart empty', async () => {
      checkoutService.create.mockRejectedValue(new BadRequestException());
      await expect(
        service.create(1, { address: 'a', phone: 'p' } as any),
      ).rejects.toThrow(BadRequestException);
    });

    it('should return order with items on success', async () => {
      checkoutService.create.mockResolvedValue({ id: 100 });
      orderRepo.findOne.mockResolvedValue({ id: 100, userId: 1 });
      orderItemRepo.find.mockResolvedValue([{ id: 1, orderId: 100 }]);

      const result = await service.create(1, { address: 'a', phone: 'p' } as any);

      expect(checkoutService.create).toHaveBeenCalledWith(1, { address: 'a', phone: 'p' });
      expect(result).toEqual(
        expect.objectContaining({ id: 100, items: [{ id: 1, orderId: 100 }] }),
      );
    });

    it('should propagate error from checkoutService', async () => {
      checkoutService.create.mockRejectedValue(new Error('db down'));
      await expect(
        service.create(1, { address: 'a', phone: 'p' } as any),
      ).rejects.toThrow('db down');
    });
  });

  describe('findAll', () => {
    it('should apply status filter', async () => {
      const qb = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getCount: jest.fn().mockResolvedValue(0),
        orderBy: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([]),
      };
      orderRepo.createQueryBuilder.mockReturnValue(qb);
      const r = await service.findAll(1, { status: 1, page: 2, limit: 5 });
      expect(qb.andWhere).toHaveBeenCalledWith('o.status = :status', {
        status: 1,
      });
      expect(qb.skip).toHaveBeenCalledWith(5);
      expect(qb.take).toHaveBeenCalledWith(5);
      expect(r.page).toBe(2);
    });

    it('should default page/limit', async () => {
      const qb = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getCount: jest.fn().mockResolvedValue(0),
        orderBy: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([]),
      };
      orderRepo.createQueryBuilder.mockReturnValue(qb);
      const r = await service.findAll(1, {});
      expect(qb.skip).toHaveBeenCalledWith(0);
      expect(qb.take).toHaveBeenCalledWith(10);
    });
  });

  describe('findOne', () => {
    it('should throw NotFound when order missing', async () => {
      orderRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(1, 999)).rejects.toThrow(NotFoundException);
    });

    it('should return order with items', async () => {
      orderRepo.findOne.mockResolvedValue({ id: 1 });
      orderItemRepo.find.mockResolvedValue([{ id: 1 }]);
      const r = await service.findOne(1, 1);
      expect(r.items).toEqual([{ id: 1 }]);
    });
  });

  describe('cancel', () => {
    it('should throw NotFound when order missing', async () => {
      lifecycleService.cancel.mockRejectedValue(new NotFoundException());
      await expect(service.cancel(1, 999)).rejects.toThrow(NotFoundException);
      expect(lifecycleService.cancel).toHaveBeenCalledWith(1, 999, expect.any(Function));
    });

    it('should throw BadRequest when not PENDING', async () => {
      lifecycleService.cancel.mockRejectedValue(new BadRequestException());
      await expect(service.cancel(1, 1)).rejects.toThrow(BadRequestException);
    });

    it('should delegate to lifecycleService and return result', async () => {
      const expected = { id: 1, status: OrderStatus.CANCELLED };
      lifecycleService.cancel.mockResolvedValue(expected);
      orderRepo.findOne.mockResolvedValue(expected);
      const result = await service.cancel(1, 1);
      expect(result).toEqual(expected);
    });
  });
});
