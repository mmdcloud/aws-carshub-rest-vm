#! /bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y
# Installing Nginx
sudo apt-get install -y nginx
# Installing Node.js
curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install nodejs -y
# Installing PM2
sudo npm i -g pm2
# Installing Nest CLI
sudo npm install -g @nestjs/cli
cd /home/ubuntu
mkdir nodeapp
# Checking out from Version Control
git clone https://github.com/mmdcloud/carshub-rest
cd carshub-rest/backend/api
cp -r . /home/ubuntu/nodeapp/
cd /home/ubuntu/nodeapp/

# cat > .env <<EOL
# DB_PATH=${DB_PATH}
# UN=${UN}
# CREDS=${CREDS}
# EOL

cat > src/database.providers.ts <<EOL
import { Sequelize } from 'sequelize-typescript';
import { User } from './users/entities/user.entity';
import { Brand } from './brands/entities/brand.entity';
import { Buyer } from './buyers/entities/buyer.entity';
import { VehicleModel } from './vehicle-models/entities/vehicle-model.entity';
import { VehicleOwner } from './vehicle-owners/entities/vehicle-owner.entity';
import { ExtraService } from './extra-services/entities/extra-service.entity';
import { Order } from './orders/entities/order.entity';
import { Inventory } from './inventory/entities/inventory.entity';
import { InventoryImage } from './inventory/entities/inventory-image.entity';

export const databaseProviders = [
    {
        provide: 'SEQUELIZE',
        useFactory: async () => {
            const sequelize = new Sequelize({
                dialect: 'mysql',
                host: "${DB_PATH}",
                port: 3306,
                // dialectOptions:{
                //     sockerPath:process.env.DB_PATH
                // },
                username: "${UN}",
                password: "${CREDS}",                
                database: 'carshub',
            });
            sequelize.addModels([
                User, Brand, Buyer, VehicleModel, VehicleOwner, ExtraService,
                Order, Inventory, InventoryImage
            ]);
            await sequelize.sync({
                force: false,
            });
            return sequelize;
        },
    },
];

EOL

# Copying Nginx config
cp scripts/default /etc/nginx/sites-available/
# Installing dependencies
sudo npm i

# Building the project
sudo npm run build
# Starting PM2 app
pm2 start dist/main.js
sudo service nginx restart

# Installing AWS CloudWatch Agent
sudo apt-get update
sudo apt-get install -y wget curl unzip
wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
sudo apt-get install -f
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent
sudo systemctl status amazon-cloudwatch-agent
echo "CloudWatch agent installation completed"