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
let lastBucketCleanupAt = 0;

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

    if (await requestBodyExceedsLimit(context.req.raw, maxBodyBytes)) {
      throw new AppError(
        'REQUEST_TOO_LARGE',
        'AI request body is too large',
        413,
        { maxBodyBytes },
      );
    }

    const token = context.req.header('authorization') ?? 'anonymous';
    const now = Date.now();
    if (now - lastBucketCleanupAt >= windowMs) {
      for (const [key, value] of requestBuckets) {
        if (value.resetAt <= now) requestBuckets.delete(key);
      }
      lastBucketCleanupAt = now;
    }
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

async function requestBodyExceedsLimit(request: Request, limit: number) {
  const reader = request.clone().body?.getReader();
  if (!reader) {
    return false;
  }

  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        return false;
      }
      total += value.byteLength;
      if (total > limit) {
        await reader.cancel();
        return true;
      }
    }
  } finally {
    reader.releaseLock();
  }
}

export function resetAiGuardForTests() {
  requestBuckets.clear();
  lastBucketCleanupAt = 0;
}
