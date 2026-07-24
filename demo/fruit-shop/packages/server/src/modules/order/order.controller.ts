import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from 'shared';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { OrderService } from './order.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { QueryOrderDto } from './dto/query-order.dto';
import { ShipDto } from './dto/ship.dto';
import { RefundRequestDto } from './dto/refund-request.dto';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrderController {
  constructor(private readonly orderService: OrderService) {}

  @Post()
  create(@CurrentUser('id') userId: number, @Body() dto: CreateOrderDto) {
    return this.orderService.create(userId, dto);
  }

  @Get()
  findAll(@CurrentUser('id') userId: number, @Query() query: QueryOrderDto) {
    return this.orderService.findAll(userId, query);
  }

  // Admin 路由必须放在 :id 路由之前，避免被 :id 捕获
  @Post('admin/:id/ship')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  adminShip(@Param('id', ParseIntPipe) id: number, @Body() dto: ShipDto) {
    return this.orderService.ship(id, dto);
  }

  @Get(':id')
  findOne(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.orderService.findOne(userId, id);
  }

  @Put(':id/cancel')
  cancel(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.orderService.cancel(userId, id);
  }

  @Put(':id/pay')
  pay(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.orderService.pay(userId, id);
  }

  @Put(':id/confirm')
  confirm(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.orderService.confirm(userId, id);
  }

  @Post(':id/refund')
  requestRefund(
    @CurrentUser('id') userId: number,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RefundRequestDto,
  ) {
    return this.orderService.requestRefund(userId, id, dto);
  }

  @Get(':id/shipping')
  findShipping(@Param('id', ParseIntPipe) id: number) {
    return this.orderService.findShipping(id);
  }
}
