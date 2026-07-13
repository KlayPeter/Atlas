import type { MiddlewareHandler } from 'hono';

import { AppError } from '../shared/app_error';

const deviceTokenLifetimeMs = 1000 * 60 * 60 * 24 * 30;
const issuedTokens = new Map<string, number>();

export function createDeviceToken(now = Date.now()) {
  removeExpiredTokens(now);
  const token = crypto.randomUUID();
  const expiresAt = now + deviceTokenLifetimeMs;
  issuedTokens.set(token, expiresAt);
  return { token, expiresAt };
}

export function requireDeviceToken(): MiddlewareHandler {
  return async (context, next) => {
    const header = context.req.header('authorization') ?? '';
    const token = header.replace(/^Bearer\s+/i, '');
    const now = Date.now();
    const expiresAt = issuedTokens.get(token);
    if (!token || !expiresAt || expiresAt <= now) {
      if (token) issuedTokens.delete(token);
      throw new AppError('UNAUTHORIZED', 'Missing or invalid device token', 401);
    }
    context.set('deviceToken', token);
    await next();
  };
}

function removeExpiredTokens(now: number) {
  for (const [token, expiresAt] of issuedTokens) {
    if (expiresAt <= now) issuedTokens.delete(token);
  }
}

export function resetAuthForTests() {
  issuedTokens.clear();
}
