import { Module } from '@nestjs/common';
import { DebugUtf8Controller } from './debug.controller';

@Module({
  controllers: [DebugUtf8Controller],
})
export class DebugModule {}
