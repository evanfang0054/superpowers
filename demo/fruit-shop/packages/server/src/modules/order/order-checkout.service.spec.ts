import { BadRequestException } from '@nestjs/common';
import { OrderCheckoutService } from './order-checkout.service';
import { CartEntity, AddressEntity, UserCouponEntity } from '../../entities';
import { ErrorCode } from 'shared';

describe('OrderCheckoutService', () => {
  let service: OrderCheckoutService;
  let cartRepo: any;
  let addressRepo: any;
  let userCouponRepo: any;
  let cartService: any;
  let couponService: any;
  let dataSource: any;
  let queryRunner: any;
  let logger: any;

  beforeEach(() => {
    const deleteQb = {
      delete: jest.fn().mockReturnThis(),
      from: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue(undefined),
    };
    const managerQuery = jest.fn().mockResolvedValue([]);

    queryRunner = {
      connect: jest.fn(),
      startTransaction: jest.fn(),
      manager: {
        query: managerQuery,
        create: jest.fn((_, x) => x),
        save: jest.fn(),
        createQueryBuilder: jest.fn(() => deleteQb),
      },
      commitTransaction: jest.fn(),
      rollbackTransaction: jest.fn(),
      release: jest.fn(),
    };
    dataSource = { createQueryRunner: jest.fn(() => queryRunner) };
    cartRepo = { find: jest.fn() };
    addressRepo = { findOne: jest.fn() };
    userCouponRepo = {};
    cartService = {};
    couponService = {
      getTemplate: jest.fn(),
      calculateDiscount: jest.fn().mockReturnValue(0),
    };
    logger = { setContext: jest.fn(), info: jest.fn() };

    service = new OrderCheckoutService(
      cartRepo,
      addressRepo,
      userCouponRepo,
      cartService,
      couponService,
      dataSource,
      logger,
    );
  });

  describe('create', () => {
    it('should throw CART_EMPTY when cart has no items', async () => {
      cartRepo.find.mockResolvedValue([]);

      await expect(service.create(1, { address: 'a', phone: 'p' } as any)).rejects.toThrow(
        BadRequestException,
      );

      // Short-circuits before touching the transaction
      expect(dataSource.createQueryRunner).not.toHaveBeenCalled();
    });

    it('should throw STOCK_INSUFFICIENT and rollback when stock < quantity', async () => {
      cartRepo.find.mockResolvedValue([
        {
          productId: 1,
          specLabel: '1kg',
          quantity: 10,
          product: { id: 1, name: 'Apple', price: '9.9', image: 'i', categoryId: 1 },
        },
      ]);
      // FOR UPDATE returns stock=2 which is insufficient for quantity=10
      queryRunner.manager.query.mockResolvedValueOnce([{ id: 1, stock: 2, name: 'Apple' }]);

      await expect(service.create(1, { address: 'a', phone: 'p' } as any)).rejects.toThrow(
        BadRequestException,
      );

      expect(queryRunner.rollbackTransaction).toHaveBeenCalled();
      expect(queryRunner.release).toHaveBeenCalled();
    });
  });
});
