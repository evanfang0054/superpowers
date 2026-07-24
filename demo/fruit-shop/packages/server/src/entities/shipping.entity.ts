import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('shippings')
export class ShippingEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'order_id' })
  orderId: number;

  @Column({ length: 100 })
  company: string;

  @Column({ name: 'tracking_no', length: 100 })
  trackingNo: string;

  @Column({ name: 'shipped_at', type: 'timestamp' })
  shippedAt: Date;

  @Column({ type: 'smallint', default: 0 })
  status: number;

  @CreateDateColumn()
  createdAt: Date;
}
