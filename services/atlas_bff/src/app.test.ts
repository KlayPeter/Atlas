import { describe, expect, test } from 'bun:test';

import { createApp } from './app';
import { resetAiGuardForTests } from './middleware/ai_guard';

describe('atlas bff', () => {
  const explainBody = {
    selectedText: 'local-first',
    context: {
      documentId: 'doc_1',
      title: 'Atlas',
      outline: '- MVP',
      excerpt: 'Atlas keeps reading local-first.',
    },
  };

  async function deviceToken(app: ReturnType<typeof createApp>) {
    const authResponse = await app.request('/v1/auth/device', { method: 'POST' });
    const authBody = await authResponse.json();
    return authBody.data.token as string;
  }

  test('returns health envelope', async () => {
    const app = createApp();
    const response = await app.request('/health');
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.data.status).toBe('ok');
  });

  test('requires device token for ai routes', async () => {
    const app = createApp();
    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      body: JSON.stringify({}),
    });
    const body = await response.json();

    expect(response.status).toBe(401);
    expect(body.ok).toBe(false);
    expect(body.error.code).toBe('UNAUTHORIZED');
  });

  test('returns mock explain response with a device token', async () => {
    resetAiGuardForTests();
    const app = createApp();
    const token = await deviceToken(app);

    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(explainBody),
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.data.explanation).toContain('local-first');
  });

  test('rejects oversized ai request bodies', async () => {
    resetAiGuardForTests();
    const app = createApp();
    const token = await deviceToken(app);

    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
        'content-length': `${65 * 1024}`,
      },
      body: JSON.stringify(explainBody),
    });
    const body = await response.json();

    expect(response.status).toBe(413);
    expect(body.ok).toBe(false);
    expect(body.error.code).toBe('REQUEST_TOO_LARGE');
  });

  test('rate limits repeated ai requests by device token', async () => {
    resetAiGuardForTests();
    const app = createApp();
    const token = await deviceToken(app);

    let response = new Response();
    for (let index = 0; index < 21; index += 1) {
      response = await app.request('/v1/ai/explain', {
        method: 'POST',
        headers: {
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify(explainBody),
      });
    }
    const body = await response.json();

    expect(response.status).toBe(429);
    expect(body.ok).toBe(false);
    expect(body.error.code).toBe('RATE_LIMITED');
  });
});
