import { IsString, IsOptional, IsInt, IsIn, Min, MinLength, MaxLength } from 'class-validator';

export class UpdateBannerDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  subtitle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  image?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  ctaText?: string;

  @IsOptional()
  @IsIn(['none', 'product', 'category', 'external'])
  linkType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  linkValue?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsInt()
  @IsIn([0, 1])
  status?: number;
}
