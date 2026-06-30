import type { Hono } from 'hono';

import { env } from '../shared/env';
import { successResponse } from '../shared/http';

export function registerHealthRoutes(app: Hono) {
  app.get('/health', (context) => {
    return context.json(
      successResponse({
        status: 'ok',
        service: 'atlas-bff',
        environment: env.APP_ENV,
      }),
    );
  });
}
