import { NotFoundException } from '@nestjs/common';
import { CartService } from './cart.service';

describe('CartService', () => {
  let service: CartService;
  let cartRepo: any;
  let productRepo: any;
  let dataSource: any;

  beforeEach(() => {
    cartRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn((x) => x),
      save: jest.fn(),
      remove: jest.fn(),
      createQueryBuilder: jest.fn(),
    };
    productRepo = { findOne: jest.fn() };
    dataSource = {};
    service = new CartService(cartRepo, productRepo, dataSource);
  });

  describe('findAll', () => {
    it('should map fields and handle null product', async () => {
      cartRepo.find.mockResolvedValue([
        {
          id: 1,
          userId: 10,
          productId: 100,
          specLabel: '1kg',
          quantity: 2,
          createdAt: new Date(),
          updatedAt: new Date(),
          product: {
            id: 100,
            name: 'Apple',
            price: 9.9,
            originalPrice: 12,
            image: 'i',
            unit: '斤',
            stock: 50,
            status: 1,
          },
        },
        {
          id: 2,
          userId: 10,
          productId: 200,
          specLabel: '2kg',
          quantity: 1,
          createdAt: new Date(),
          updatedAt: new Date(),
          product: null,
        },
      ]);

      const result = await service.findAll(10);

      expect(result).toHaveLength(2);
      expect(result[0].product).toMatchObject({ id: 100, name: 'Apple' });
      expect(result[1].product).toBeNull();
    });
  });

  describe('add', () => {
    it('should throw NotFound when product missing', async () => {
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.add(10, { productId: 999, specLabel: '1kg' })).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should merge quantity when item exists', async () => {
      productRepo.findOne.mockResolvedValue({ id: 1 });
      const existing = { id: 5, userId: 10, productId: 1, specLabel: '1kg', quantity: 2 };
      cartRepo.findOne.mockResolvedValue(existing);
      cartRepo.find.mockResolvedValue([]);

      await service.add(10, { productId: 1, specLabel: '1kg', quantity: 3 });

      expect(existing.quantity).toBe(5);
      expect(cartRepo.save).toHaveBeenCalledWith(existing);
    });

    it('should create new item when not exists, default quantity 1', async () => {
      productRepo.findOne.mockResolvedValue({ id: 1 });
      cartRepo.findOne.mockResolvedValue(null);
      cartRepo.create.mockImplementation((x: any) => x);
      cartRepo.find.mockResolvedValue([]);

      await service.add(10, { productId: 1, specLabel: '1kg' });

      expect(cartRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 1 }));
    });
  });

  describe('update', () => {
    it('should throw NotFound when item missing', async () => {
      cartRepo.findOne.mockResolvedValue(null);
      await expect(service.update(1, 10, { quantity: 3 })).rejects.toThrow(NotFoundException);
    });

    it('should update quantity', async () => {
      const item = { id: 1, userId: 10, quantity: 2 };
      cartRepo.findOne.mockResolvedValue(item);
      cartRepo.find.mockResolvedValue([]);
      await service.update(1, 10, { quantity: 5 });
      expect(item.quantity).toBe(5);
      expect(cartRepo.save).toHaveBeenCalledWith(item);
    });
  });

  describe('remove', () => {
    it('should throw NotFound when item missing', async () => {
      cartRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(1, 10)).rejects.toThrow(NotFoundException);
    });

    it('should call remove', async () => {
      const item = { id: 1, userId: 10 };
      cartRepo.findOne.mockResolvedValue(item);
      cartRepo.find.mockResolvedValue([]);
      await service.remove(1, 10);
      expect(cartRepo.remove).toHaveBeenCalledWith(item);
    });
  });

  describe('removeByUserAndProductIds', () => {
    it('should noop when productIds empty', async () => {
      await service.removeByUserAndProductIds(10, []);
      expect(cartRepo.createQueryBuilder).not.toHaveBeenCalled();
    });

    it('should execute delete when non-empty', async () => {
      const execute = jest.fn();
      const qb = {
        delete: jest.fn().mockReturnThis(),
        from: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute,
      };
      cartRepo.createQueryBuilder.mockReturnValue(qb);
      await service.removeByUserAndProductIds(10, [1, 2]);
      expect(execute).toHaveBeenCalled();
    });
  });
});
