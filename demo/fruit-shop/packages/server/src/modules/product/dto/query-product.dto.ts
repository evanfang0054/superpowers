import { IsOptional, IsString, IsInt, Min, IsNumber, IsIn } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationQuery } from 'shared';

export type ProductSortBy = 'created_desc' | 'price_asc' | 'price_desc' | 'sales_desc';

export const PRODUCT_SORT_BY_LIST: ProductSortBy[] = [
  'created_desc',
  'price_asc',
  'price_desc',
  'sales_desc',
];

export class QueryProductDto implements PaginationQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  categoryId?: number;

  @IsOptional()
  @IsString()
  keyword?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  minPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  maxPrice?: number;

  @IsOptional()
  @IsString()
  origin?: string;

  @IsOptional()
  @IsString()
  @IsIn(PRODUCT_SORT_BY_LIST)
  sortBy?: ProductSortBy;
}
