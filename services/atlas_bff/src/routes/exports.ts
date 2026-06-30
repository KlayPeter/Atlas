import type { Hono } from 'hono';
import { z } from 'zod';

import { requireDeviceToken } from '../middleware/auth';
import { successResponse } from '../shared/http';

const htmlEnhanceRequestSchema = z.object({
  context: z.object({
    documentId: z.string().min(1),
    title: z.string().min(1),
    outline: z.string().default(''),
    excerpt: z.string().min(1).max(12000),
  }),
  mode: z.enum(['summary', 'study']).default('summary'),
});

export function registerExportRoutes(app: Hono) {
  app.post('/v1/exports/html/enhance', requireDeviceToken(), async (context) => {
    const request = htmlEnhanceRequestSchema.parse(await context.req.json());
    return context.json(
      successResponse({
        title: request.context.title,
        lead: 'HTML enhance 接口已预留；当前 Flutter 使用本地忠实转换。',
        summary: '',
        sections: [],
        keyConcepts: [],
        questions: [],
      }),
    );
  });
}
