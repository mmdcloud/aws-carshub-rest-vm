import { InventoryImages } from "../entities/inventory-images.entity";
import { Inventory } from "../entities/inventory.entity";

export class InventoryDetailsDto {
    imageData:InventoryImages[];
    inventoryData:Inventory;
    documentData:InventoryImages[];
}
