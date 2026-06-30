import { describe, expect, test } from 'bun:test';

import { createApp } from './app';

describe('atlas bff', () => {
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
    const app = createApp();
    const authResponse = await app.request('/v1/auth/device', { method: 'POST' });
    const authBody = await authResponse.json();

    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${authBody.data.token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        selectedText: 'local-first',
        context: {
          documentId: 'doc_1',
          title: 'Atlas',
          outline: '- MVP',
          excerpt: 'Atlas keeps reading local-first.',
        },
      }),
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.data.explanation).toContain('local-first');
  });
});
