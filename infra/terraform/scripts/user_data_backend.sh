#! /bin/bash
set -e
exec > /var/log/user-data.log 2>&1
sudo apt-get update -y
sudo apt-get upgrade -y
# Installing Nginx, jq, awscli
sudo apt-get install -y nginx jq awscli
# Installing Node.js
curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install nodejs -y
# Installing PM2
sudo npm i -g pm2
# Installing Nest CLI
sudo npm install -g @nestjs/cli
cd /home/ubuntu
mkdir -p nodeapp
# Checking out from Version Control
git clone https://github.com/mmdcloud/carshub-rest
cd carshub-rest/src/backend/api
cp -r . /home/ubuntu/nodeapp/
cd /home/ubuntu/nodeapp/

# Retrieve database credentials dynamically from Secrets Manager if SECRET_NAME is provided
DB_USER="${UN}"
DB_PASSWORD="${CREDS}"

if [ -n "${SECRET_NAME}" ]; then
  SECRET_PAYLOAD=$(aws secretsmanager get-secret-value --secret-id "${SECRET_NAME}" --region "${REGION}" --query SecretString --output text 2>/dev/null || echo "")
  if [ -n "$SECRET_PAYLOAD" ]; then
    RESOLVED_USER=$(echo "$SECRET_PAYLOAD" | jq -r '.username // empty')
    RESOLVED_PASS=$(echo "$SECRET_PAYLOAD" | jq -r '.password // empty')
    [ -n "$RESOLVED_USER" ] && DB_USER="$RESOLVED_USER"
    [ -n "$RESOLVED_PASS" ] && DB_PASSWORD="$RESOLVED_PASS"
  fi
fi

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
                username: "$DB_USER",
                password: "$DB_PASSWORD",                
                database: '${DB_NAME}',
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
