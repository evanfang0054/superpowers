import { NotFoundException } from '@nestjs/common';
import { UserService } from './user.service';

describe('UserService', () => {
  let service: UserService;
  let userRepo: any;

  beforeEach(() => {
    userRepo = {
      findOne: jest.fn(),
      save: jest.fn(),
    };
    service = new UserService(userRepo);
  });

  describe('getProfile', () => {
    it('should return user when found', async () => {
      const user = { id: 1, phone: '13800000001', role: 'user' };
      userRepo.findOne.mockResolvedValue(user);

      const result = await service.getProfile(1);

      expect(result).toEqual(user);
      expect(userRepo.findOne).toHaveBeenCalledWith({ where: { id: 1 } });
    });

    it('should throw NotFoundException when user not found', async () => {
      userRepo.findOne.mockResolvedValue(null);

      await expect(service.getProfile(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe('updateProfile', () => {
    it('should update and return user', async () => {
      const user = { id: 1, nickname: 'old' };
      userRepo.findOne.mockResolvedValue(user);
      userRepo.save.mockResolvedValue({ ...user, nickname: 'new' });

      const result = await service.updateProfile(1, { nickname: 'new' });

      expect(result.nickname).toBe('new');
      expect(userRepo.save).toHaveBeenCalled();
    });

    it('should throw NotFoundException when user not found', async () => {
      userRepo.findOne.mockResolvedValue(null);

      await expect(service.updateProfile(999, { nickname: 'x' })).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
