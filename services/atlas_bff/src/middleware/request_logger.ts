import type { MiddlewareHandler } from 'hono';

export function requestLogger(): MiddlewareHandler {
  return async (context, next) => {
    const startedAt = performance.now();
    await next();
    const durationMs = Math.round(performance.now() - startedAt);
    console.info(
      `${context.req.method} ${context.req.path} ${context.res.status} ${durationMs}ms`,
    );
  };
}
