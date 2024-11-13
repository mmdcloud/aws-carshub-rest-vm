import { Inject, Injectable } from '@nestjs/common';
import { UpdateInventoryDto } from './dto/update-inventory.dto';
import { Inventory } from './entities/inventory.entity';
const AWS = require('aws-sdk');

@Injectable()
export class InventoryService {
  constructor(
    @Inject('INVENTORY_REPOSITORY')
    private inventoryRepository: typeof Inventory
  ) { }

  async getSignedUrl(payload): Promise<object> {
    var urls = [];
    const s3 = new AWS.S3({
      signatureVersion: 'v4', region: "us-east-1"
    });
    const myBucket = 'theplayer007-vehicle-images';
    const signedUrlExpireSeconds = 60 * 5;
    for (var i of payload.files) {
      const myKey = i;
      const url = await s3.getSignedUrlPromise('putObject', {
        Bucket: myBucket,
        Key: myKey,
        Expires: signedUrlExpireSeconds
      });
      urls.push(url);
    }
    const response = {
      statusCode: 200,
      body: urls,
    };
    return response;
  }

  async create(createInventoryDto): Promise<Inventory> {
    const record = new Inventory(createInventoryDto);
    let indianDate = new Date().toLocaleString("en-Us", { timeZone: 'Asia/Kolkata' });
    record.day = new Date(indianDate).getDay();
    record.month = (new Date(indianDate).getMonth() + 1);
    record.year = new Date(indianDate).getFullYear();
    record.status = "Pending";
    return await record.save();
  }

  async findAll(): Promise<Inventory[]> {
    return this.inventoryRepository.findAll<Inventory>({
      include: ["model", "owner"]
    });
  }

  async findOne(id: number): Promise<Inventory> {
    return this.inventoryRepository.findByPk<Inventory>(id, {
      include: ["model", "owner"]
    });
  }

  async update(id: number, updateInventoryDto: UpdateInventoryDto): Promise<[number, Inventory[]]> {
    const [affectedCount, affectedRows] = await this.inventoryRepository.update(updateInventoryDto, {
      where: { id },
      returning: true,
    });
    return [affectedCount, affectedRows as Inventory[]];
  }

  async remove(id: number): Promise<number> {
    return this.inventoryRepository.destroy({ where: { id: id } });
  }
}
