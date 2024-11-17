import { InventoryImages } from './entities/inventory-images.entity';
import { Inventory } from './entities/inventory.entity';

export const inventoryProviders = [
    {
        provide: 'INVENTORY_REPOSITORY',
        useValue: Inventory,
    },
    {
        provide: 'INVENTORY_IMAGES_REPOSITORY',
        useValue: InventoryImages,
    },
];