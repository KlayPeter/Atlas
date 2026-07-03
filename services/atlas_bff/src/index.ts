import { createApp } from './app';
import { env } from './shared/env';

const app = createApp();

Bun.serve({
  fetch: app.fetch,
  hostname: env.HOST,
  port: env.PORT,
});

console.info(`Atlas BFF listening on http://${env.HOST}:${env.PORT}`);
