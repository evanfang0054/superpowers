import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { AddressEntity } from '../../entities/address.entity';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';
import { ErrorCode, ErrorMessage } from 'shared';

@Injectable()
export class AddressService {
  constructor(
    @InjectRepository(AddressEntity)
    private readonly addressRepo: Repository<AddressEntity>,
    private readonly dataSource: DataSource,
  ) {}

  /**
   * 返回当前用户全部地址，默认地址排首位，其余按 createdAt DESC。
   */
  async findAll(userId: number) {
    const list = await this.addressRepo.find({
      where: { userId },
      order: { isDefault: 'DESC', createdAt: 'DESC' },
    });
    return list;
  }

  async create(userId: number, dto: CreateAddressDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      // 若新建地址为默认，先把该用户其他地址全部置非默认
      if (dto.isDefault) {
        await queryRunner.manager
          .createQueryBuilder()
          .update(AddressEntity)
          .set({ isDefault: false })
          .where('user_id = :userId', { userId })
          .execute();
      }
      const address = queryRunner.manager.create(AddressEntity, {
        ...dto,
        userId,
      });
      const saved = await queryRunner.manager.save(AddressEntity, address);
      await queryRunner.commitTransaction();
      return saved;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async update(userId: number, id: number, dto: UpdateAddressDto) {
    const address = await this.addressRepo.findOne({
      where: { id, userId },
    });
    if (!address) {
      throw new NotFoundException({
        code: ErrorCode.ADDRESS_NOT_FOUND,
        message: ErrorMessage[ErrorCode.ADDRESS_NOT_FOUND],
      });
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      if (dto.isDefault) {
        await queryRunner.manager
          .createQueryBuilder()
          .update(AddressEntity)
          .set({ isDefault: false })
          .where('user_id = :userId AND id != :id', { userId, id })
          .execute();
      }
      Object.assign(address, dto);
      const saved = await queryRunner.manager.save(AddressEntity, address);
      await queryRunner.commitTransaction();
      return saved;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async remove(userId: number, id: number) {
    const address = await this.addressRepo.findOne({
      where: { id, userId },
    });
    if (!address) {
      throw new NotFoundException({
        code: ErrorCode.ADDRESS_NOT_FOUND,
        message: ErrorMessage[ErrorCode.ADDRESS_NOT_FOUND],
      });
    }
    if (address.isDefault) {
      throw new BadRequestException({
        code: ErrorCode.ADDRESS_IS_DEFAULT,
        message: ErrorMessage[ErrorCode.ADDRESS_IS_DEFAULT],
      });
    }
    await this.addressRepo.remove(address);
    return null;
  }

  /**
   * 设置默认地址：事务内先把用户所有地址置非默认，再把目标置默认。
   */
  async setDefault(userId: number, id: number) {
    const address = await this.addressRepo.findOne({
      where: { id, userId },
    });
    if (!address) {
      throw new NotFoundException({
        code: ErrorCode.ADDRESS_NOT_FOUND,
        message: ErrorMessage[ErrorCode.ADDRESS_NOT_FOUND],
      });
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      await queryRunner.manager
        .createQueryBuilder()
        .update(AddressEntity)
        .set({ isDefault: false })
        .where('user_id = :userId', { userId })
        .execute();
      await queryRunner.manager
        .createQueryBuilder()
        .update(AddressEntity)
        .set({ isDefault: true })
        .where('id = :id AND user_id = :userId', { id, userId })
        .execute();
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }

    return this.addressRepo.findOne({ where: { id, userId } });
  }

  /**
   * 内部使用：根据 id + userId 读取地址（供 OrderService 快照）。
   */
  async findOneOwned(userId: number, id: number) {
    return this.addressRepo.findOne({ where: { id, userId } });
  }
}
