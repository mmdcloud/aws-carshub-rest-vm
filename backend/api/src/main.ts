import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(
    AppModule,
  );
  app.enableCors({
  origin: [
    'http://localhost:3000',
    ],
  	methods: ["GET","POST","PATCH","DELETE","PUT"],
  });
  app.setBaseViewsDir(join(__dirname, '..', 'static'));
  app.setViewEngine('ejs');
  await app.listen(3001);
}
bootstrap();
