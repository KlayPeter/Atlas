import { Hono } from 'hono';

import { requestLogger } from './middleware/request_logger';
import { registerHealthRoutes } from './routes/health';
import { AppError } from './shared/app_error';
import { errorResponse, successResponse } from './shared/http';

export function createApp() {
  const app = new Hono();

  app.use('*', requestLogger());

  registerHealthRoutes(app);

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
