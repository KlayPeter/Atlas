import { timingSafeEqual } from 'node:crypto';
import type { MiddlewareHandler } from 'hono';

import { AppError } from '../shared/app_error';

export function requireBffAccessToken(
  expectedToken?: string,
): MiddlewareHandler {
  return async (context, next) => {
    if (!expectedToken) {
      await next();
      return;
    }

    const suppliedToken = context.req.header('x-atlas-access-token') ?? '';
    const expected = Buffer.from(expectedToken);
    const supplied = Buffer.from(suppliedToken);
    if (
      expected.length !== supplied.length ||
      !timingSafeEqual(expected, supplied)
    ) {
      throw new AppError('UNAUTHORIZED', 'Invalid Atlas BFF access token', 401);
    }

    await next();
  };
}
