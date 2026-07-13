import type { Hono } from 'hono';

import { createDeviceToken } from '../middleware/auth';
import { successResponse } from '../shared/http';

export function registerAuthRoutes(app: Hono) {
  app.post('/v1/auth/device', (context) => {
    const { token, expiresAt } = createDeviceToken();
    return context.json(
      successResponse({
        token,
        expiresAt: new Date(expiresAt).toISOString(),
      }),
    );
  });
}
