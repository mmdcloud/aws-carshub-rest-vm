#!/bin/bash
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
# Copying Nginx config
cp scripts/default /etc/nginx/sites-available/
# Installing dependencies
sudo npm i

# Copying DB crendetials 
cat > src/database.providers.ts << EOL
import { Sequelize } from 'sequelize-typescript';
import { User } from './users/entities/user.entity';
import { Brand } from './brands/entities/brand.entity';
import { Buyer } from './buyers/entities/buyer.entity';
import { VehicleModel } from './vehicle-models/entities/vehicle-model.entity';
import { VehicleOwner } from './vehicle-owners/entities/vehicle-owner.entity';
import { ExtraService } from './extra-services/entities/extra-service.entity';
import { Order } from './orders/entities/order.entity';
import { InventoryImage } from './inventory/entities/inventory-image.entity';
import { Inventory } from './inventory/entities/inventory.entity';

export const databaseProviders = [
     {
            provide: 'SEQUELIZE',
            useFactory: async () => {
                const sequelize = new Sequelize({
                    dialect: 'mysql',
                    host: '${db_path}',
                    port: 3306,
                    username: '${username}',
                    password: '${password}',
                    database: 'carshub',
                });
                sequelize.addModels([
                    User, Brand, Buyer, VehicleModel, VehicleOwner, ExtraService,
                    Order, Inventory, InventoryImage
                ]);
                await sequelize.sync({
                    force: true
                });
                return sequelize;
            },
      },
];
EOL
# Building the project
sudo npm run build
# Starting PM2 app
pm2 start dist/main.js
sudo service nginx restart
# Installing CodeDeploy agent
sudo apt-get install ruby-full ruby-webrick wget -y
cd /tmp
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/releases/codedeploy-agent_1.3.2-1902_all.deb
mkdir codedeploy-agent_1.3.2-1902_ubuntu22
dpkg-deb -R codedeploy-agent_1.3.2-1902_all.deb codedeploy-agent_1.3.2-1902_ubuntu22
sed 's/Depends:.*/Depends:ruby3.0/' -i ./codedeploy-agent_1.3.2-1902_ubuntu22/DEBIAN/control
dpkg-deb -b codedeploy-agent_1.3.2-1902_ubuntu22/
sudo dpkg -i codedeploy-agent_1.3.2-1902_ubuntu22.deb
sudo systemctl list-units --type=service | grep codedeploy
sudo service codedeploy-agent status
sudo service codedeploy-agent restart
