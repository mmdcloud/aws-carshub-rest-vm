import { Table, Column, Model, ForeignKey, BelongsTo } from 'sequelize-typescript';
import { Inventory } from './inventory.entity';

@Table
export class InventoryImages extends Model {

    @ForeignKey(() => Inventory)
    @Column
    inventoryId: number;

    @BelongsTo(() => Inventory)
    inventory: Inventory;

    @Column
    path: string;

    @Column
    type: string;
}