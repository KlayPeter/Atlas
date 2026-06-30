import { Hono } from 'hono';

import { requestLogger } from './middleware/request_logger';
import { registerAiRoutes, mapZodError } from './routes/ai';
import { registerAuthRoutes } from './routes/auth';
import { registerExportRoutes } from './routes/exports';
import { registerHealthRoutes } from './routes/health';
import { AppError } from './shared/app_error';
import { errorResponse, successResponse } from './shared/http';
import { ZodError } from 'zod';

export function createApp() {
  const app = new Hono();

  app.use('*', requestLogger());

  registerHealthRoutes(app);
  registerAuthRoutes(app);
  registerAiRoutes(app);
  registerExportRoutes(app);

  app.notFound((context) => {
    return context.json(
      errorResponse({
        code: 'NOT_FOUND',
        message: 'Route not found',
      }),
      404,
    );
  });

  app.onError((error, context) => {
    if (error instanceof ZodError) {
      const appError = mapZodError(error);
      return context.json(
        errorResponse({
          code: appError.code,
          message: appError.message,
          details: appError.details,
        }),
        appError.status,
      );
    }

    if (error instanceof AppError) {
      return context.json(
        errorResponse({
          code: error.code,
          message: error.message,
          details: error.details,
        }),
        error.status,
      );
    }

    console.error(error);
    return context.json(
      errorResponse({
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Unexpected server error',
      }),
      500,
    );
  });

  app.get('/', (context) => {
    return context.json(successResponse({ service: 'atlas-bff' }));
  });

  return app;
}
