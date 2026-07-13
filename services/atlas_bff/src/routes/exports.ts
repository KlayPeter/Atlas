import type { Context, Hono } from 'hono';

import { requireDeviceToken } from '../middleware/auth';
import { aiGuard } from '../middleware/ai_guard';
import { successResponse } from '../shared/http';

import { htmlEnhanceRequestSchema } from '../modules/ai/contracts';
import { createAiProvider } from '../modules/ai/ai_provider';

export function registerExportRoutes(app: Hono) {
  function getProvider(context: Context) {
    return createAiProvider({
      apiKey: context.req.header('x-ai-provider-api-key'),
      baseUrl: context.req.header('x-ai-provider-base-url'),
      model: context.req.header('x-ai-provider-model'),
    });
  }

  app.post('/v1/exports/html/enhance', requireDeviceToken(), aiGuard(), async (context) => {
    const request = htmlEnhanceRequestSchema.parse(await context.req.json());
    const result = await getProvider(context).enhanceHtml(request);
    return context.json(successResponse(result));
  });
}
