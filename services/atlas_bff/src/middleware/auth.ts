import type { MiddlewareHandler } from 'hono';

import { AppError } from '../shared/app_error';

const issuedTokens = new Set<string>();

export function createDeviceToken() {
  const token = crypto.randomUUID();
  issuedTokens.add(token);
  return token;
}

export function requireDeviceToken(): MiddlewareHandler {
  return async (context, next) => {
    const header = context.req.header('authorization') ?? '';
    const token = header.replace(/^Bearer\s+/i, '');
    if (!token || !issuedTokens.has(token)) {
      throw new AppError('UNAUTHORIZED', 'Missing or invalid device token', 401);
    }
    context.set('deviceToken', token);
    await next();
  };
}
