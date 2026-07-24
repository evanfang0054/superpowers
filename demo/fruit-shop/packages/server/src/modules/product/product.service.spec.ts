import { NotFoundException } from '@nestjs/common';
import { ProductService } from './product.service';

describe('ProductService', () => {
  let service: ProductService;
  let productRepo: any;
  let categoryRepo: any;
  let orderItemRepo: any;
  let redis: any;

  beforeEach(() => {
    const qbChain = {
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getMany: jest.fn(),
    };
    productRepo = {
      createQueryBuilder: jest.fn(() => qbChain),
      findOne: jest.fn(),
      create: jest.fn((x) => x),
      save: jest.fn(),
      remove: jest.fn(),
    };
    categoryRepo = { find: jest.fn() };
    const oiQb = {
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getQuery: jest.fn().mockReturnValue('1=1'),
    };
    orderItemRepo = { createQueryBuilder: jest.fn(() => oiQb) };
    redis = { get: jest.fn(), set: jest.fn(), keys: jest.fn(), del: jest.fn() };
    service = new ProductService(productRepo, categoryRepo, orderItemRepo, redis);
    // 暴露 qbChain 便于每用例重设
    (service as any).__qb = qbChain;
  });

  describe('findAll', () => {
    it('should return cached when hit', async () => {
      const cached = { list: [{ id: 1 }], total: 1, page: 1, limit: 10 };
      redis.get.mockResolvedValue(JSON.stringify(cached));

      const result = await service.findAll({ page: 1, limit: 10 });

      expect(result).toEqual(cached);
      expect(productRepo.createQueryBuilder).not.toHaveBeenCalled();
    });

    it('should query DB and write cache when miss', async () => {
      redis.get.mockResolvedValue(null);
      const qb = (service as any).__qb;
      qb.getCount.mockResolvedValue(1);
      qb.getMany.mockResolvedValue([{ id: 1 }]);

      const result = await service.findAll({ page: 1, limit: 10 });

      expect(result.total).toBe(1);
      expect(redis.set).toHaveBeenCalledWith(
        expect.stringMatching(/^products:/),
        expect.any(String),
        'EX',
        60,
      );
    });

    it('should apply categoryId filter', async () => {
      redis.get.mockResolvedValue(null);
      const qb = (service as any).__qb;
      qb.getCount.mockResolvedValue(0);
      qb.getMany.mockResolvedValue([]);
      await service.findAll({ categoryId: 5, page: 1, limit: 10 });
      expect(qb.andWhere).toHaveBeenCalledWith('p.category_id = :categoryId', { categoryId: 5 });
    });

    it('should apply keyword filter', async () => {
      redis.get.mockResolvedValue(null);
      const qb = (service as any).__qb;
      qb.getCount.mockResolvedValue(0);
      qb.getMany.mockResolvedValue([]);
      await service.findAll({ keyword: '苹', page: 1, limit: 10 });
      expect(qb.andWhere).toHaveBeenCalledWith('p.name LIKE :keyword', { keyword: '%苹%' });
    });
  });

  describe('findOne', () => {
    it('should return cached', async () => {
      redis.get.mockResolvedValue(JSON.stringify({ id: 1 }));
      const result = await service.findOne(1);
      expect(result.id).toBe(1);
      expect(productRepo.findOne).not.toHaveBeenCalled();
    });

    it('should throw NotFound when not found', async () => {
      redis.get.mockResolvedValue(null);
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });

    it('should write cache when found', async () => {
      redis.get.mockResolvedValue(null);
      const p = { id: 1, name: 'A' };
      productRepo.findOne.mockResolvedValue(p);
      await service.findOne(1);
      expect(redis.set).toHaveBeenCalledWith('product:1', expect.any(String), 'EX', 60);
    });
  });

  describe('create', () => {
    it('should save and clear cache', async () => {
      productRepo.save.mockResolvedValue({ id: 1 });
      redis.keys.mockResolvedValue(['products:a']);
      await service.create({ name: 'A', price: 1 } as any);
      expect(productRepo.save).toHaveBeenCalled();
      expect(redis.del).toHaveBeenCalledWith('products:a');
    });
  });

  describe('update', () => {
    it('should throw NotFound', async () => {
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.update(999, { name: 'x' } as any)).rejects.toThrow(NotFoundException);
    });

    it('should update and clear caches', async () => {
      const p = { id: 1, name: 'A' };
      productRepo.findOne.mockResolvedValue(p);
      productRepo.save.mockResolvedValue({ ...p, name: 'B' });
      redis.keys.mockResolvedValue(['products:a']);
      await service.update(1, { name: 'B' } as any);
      expect(redis.del).toHaveBeenCalledWith('products:a');
      expect(redis.del).toHaveBeenCalledWith('product:1');
    });
  });

  describe('remove', () => {
    it('should throw NotFound', async () => {
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(999)).rejects.toThrow(NotFoundException);
    });

    it('should remove and clear caches', async () => {
      const p = { id: 1 };
      productRepo.findOne.mockResolvedValue(p);
      redis.keys.mockResolvedValue(['products:a']);
      await service.remove(1);
      expect(productRepo.remove).toHaveBeenCalledWith(p);
      expect(redis.del).toHaveBeenCalledWith('product:1');
    });
  });

  describe('findAllCategories', () => {
    it('should return cached', async () => {
      redis.get.mockResolvedValue(JSON.stringify([{ id: 1 }]));
      const r = await service.findAllCategories();
      expect(r).toEqual([{ id: 1 }]);
      expect(categoryRepo.find).not.toHaveBeenCalled();
    });

    it('should query and cache 300s', async () => {
      redis.get.mockResolvedValue(null);
      categoryRepo.find.mockResolvedValue([{ id: 1 }]);
      await service.findAllCategories();
      expect(redis.set).toHaveBeenCalledWith('categories:all', expect.any(String), 'EX', 300);
    });
  });
});
