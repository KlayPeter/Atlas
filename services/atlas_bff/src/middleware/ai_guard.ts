import type { MiddlewareHandler } from 'hono';

import { AppError } from '../shared/app_error';

const maxBodyBytes = 64 * 1024;
const windowMs = 60 * 1000;
const maxRequestsPerWindow = 20;

const requestBuckets = new Map<
  string,
  {
    count: number;
    resetAt: number;
  }
>();

export function aiGuard(): MiddlewareHandler {
  return async (context, next) => {
    const contentLength = Number(context.req.header('content-length') ?? 0);
    if (contentLength > maxBodyBytes) {
      throw new AppError(
        'REQUEST_TOO_LARGE',
        'AI request body is too large',
        413,
        { maxBodyBytes },
      );
    }

    const token = context.req.header('authorization') ?? 'anonymous';
    const now = Date.now();
    const bucket = requestBuckets.get(token);

    if (!bucket || bucket.resetAt <= now) {
      requestBuckets.set(token, { count: 1, resetAt: now + windowMs });
      await next();
      return;
    }

    if (bucket.count >= maxRequestsPerWindow) {
      throw new AppError('RATE_LIMITED', 'Too many AI requests', 429, {
        retryAfterMs: bucket.resetAt - now,
      });
    }

    bucket.count += 1;
    await next();
  };
}

export function resetAiGuardForTests() {
  requestBuckets.clear();
}
