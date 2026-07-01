import type { Hono } from 'hono';
import { streamSSE } from 'hono/streaming';
import { ZodError } from 'zod';

import { aiGuard } from '../middleware/ai_guard';
import { requireDeviceToken } from '../middleware/auth';
import { createAiProvider } from '../modules/ai/ai_provider';
import {
  askRequestSchema,
  explainRequestSchema,
  summarizeRequestSchema,
  studyRequestSchema,
} from '../modules/ai/contracts';
import { AppError } from '../shared/app_error';
import { successResponse } from '../shared/http';

export function registerAiRoutes(app: Hono) {
  function getProvider(context: any) {
    return createAiProvider({
      apiKey: context.req.header('x-ai-provider-api-key'),
      baseUrl: context.req.header('x-ai-provider-base-url'),
      model: context.req.header('x-ai-provider-model'),
    });
  }

  app.post('/v1/ai/explain', requireDeviceToken(), aiGuard(), async (context) => {
    const request = explainRequestSchema.parse(await context.req.json());
    const result = await getProvider(context).explain(request);
    return context.json(successResponse(result));
  });

  app.post('/v1/ai/summarize', requireDeviceToken(), aiGuard(), async (context) => {
    const request = summarizeRequestSchema.parse(await context.req.json());
    const result = await getProvider(context).summarize(request);
    return context.json(successResponse(result));
  });

  app.post('/v1/ai/ask', requireDeviceToken(), aiGuard(), async (context) => {
    const request = askRequestSchema.parse(await context.req.json());
    const result = await getProvider(context).ask(request);
    if (!request.stream) {
      return context.json(successResponse(result));
    }

    return streamSSE(context, async (stream) => {
      await stream.writeSSE({
        event: 'chunk',
        data: JSON.stringify({ text: result.answer }),
      });
      await stream.writeSSE({
        event: 'done',
        data: JSON.stringify({ references: result.references }),
      });
    });
  });

  app.post('/v1/ai/study/questions', requireDeviceToken(), aiGuard(), async (context) => {
    const request = studyRequestSchema.parse(await context.req.json());
    const result = await getProvider(context).generateStudyQuestions(request);
    return context.json(successResponse(result));
  });
}

export function mapZodError(error: ZodError) {
  return new AppError(
    'VALIDATION_ERROR',
    'Request validation failed',
    400,
    error.issues.map((issue) => ({
      path: issue.path.join('.'),
      message: issue.message,
    })),
  );
}
