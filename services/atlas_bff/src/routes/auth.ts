import type { Hono } from 'hono';

import { createDeviceToken } from '../middleware/auth';
import { requireBffAccessToken } from '../middleware/bff_access';
import { env } from '../shared/env';
import { successResponse } from '../shared/http';

export function registerAuthRoutes(
  app: Hono,
  accessToken = env.ATLAS_BFF_ACCESS_TOKEN,
) {
  app.post('/v1/auth/device', requireBffAccessToken(accessToken), (context) => {
    const { token, expiresAt } = createDeviceToken();
    return context.json(
      successResponse({
        token,
        expiresAt: new Date(expiresAt).toISOString(),
      }),
    );
  });
}
