import { IsString, IsOptional, IsBoolean, MaxLength, MinLength, Matches } from 'class-validator';

export class CreateAddressDto {
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  recipientName: string;

  @IsString()
  @Matches(/^1[3-9]\d{9}$/, { message: '手机号格式不正确' })
  phone: string;

  @IsString()
  @MinLength(1)
  @MaxLength(50)
  province: string;

  @IsString()
  @MinLength(1)
  @MaxLength(50)
  city: string;

  @IsString()
  @MinLength(1)
  @MaxLength(50)
  district: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  detail: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}
