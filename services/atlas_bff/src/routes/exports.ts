import type { Hono } from 'hono';
import { z } from 'zod';

import { requireDeviceToken } from '../middleware/auth';
import { successResponse } from '../shared/http';

import { htmlEnhanceRequestSchema } from '../modules/ai/contracts';
import { createAiProvider } from '../modules/ai/ai_provider';

export function registerExportRoutes(app: Hono) {
  const provider = createAiProvider();

  app.post('/v1/exports/html/enhance', requireDeviceToken(), async (context) => {
    const request = htmlEnhanceRequestSchema.parse(await context.req.json());
    const result = await provider.enhanceHtml(request);
    return context.json(successResponse(result));
  });
}
