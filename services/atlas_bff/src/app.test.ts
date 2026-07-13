import { describe, expect, test } from 'bun:test';

import { createApp } from './app';
import { resetAiGuardForTests } from './middleware/ai_guard';
import { explainPrompt, htmlEnhancePrompt } from './modules/ai/prompts';

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

  test('returns configuration error when ai provider is missing', async () => {
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

    expect(response.status).toBe(503);
    expect(body.ok).toBe(false);
    expect(body.error.code).toBe('AI_PROVIDER_NOT_CONFIGURED');
    expect(body.error.message).toContain('AI 未配置');
  });

  test('rejects placeholder provider headers instead of returning mock content', async () => {
    resetAiGuardForTests();
    const app = createApp();
    const token = await deviceToken(app);

    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
        'x-ai-provider-api-key': 'xxx',
        'x-ai-provider-base-url': 'https://api.deepseek.com/v1',
        'x-ai-provider-model': 'changeme',
      },
      body: JSON.stringify(explainBody),
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.ok).toBe(false);
    expect(body.error.code).toBe('INVALID_AI_PROVIDER_CONFIG');
  });

  test('rejects provider endpoint overrides without a client-owned api key', async () => {
    resetAiGuardForTests();
    const app = createApp();
    const token = await deviceToken(app);

    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
        'x-ai-provider-base-url': 'https://attacker.example/v1',
        'x-ai-provider-model': 'stolen-key-probe',
      },
      body: JSON.stringify(explainBody),
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.ok).toBe(false);
    expect(body.error.code).toBe('INVALID_AI_PROVIDER_CONFIG');
  });

  test('rejects private-network provider endpoints to prevent SSRF', async () => {
    resetAiGuardForTests();
    const app = createApp();
    const token = await deviceToken(app);

    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
        'x-ai-provider-api-key': 'client-owned-key',
        'x-ai-provider-base-url': 'http://169.254.169.254/latest',
      },
      body: JSON.stringify(explainBody),
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.ok).toBe(false);
    expect(body.error.code).toBe('INVALID_AI_PROVIDER_CONFIG');
  });

  test('explain prompt focuses on selected term or sentence meaning', () => {
    const prompt = explainPrompt(explainBody);

    expect(prompt).toContain('Markdown');
    expect(prompt).toContain('通用含义');
    expect(prompt).toContain('原文也是这样的意思');
    expect(prompt).toContain('中文翻译');
  });

  test('html enhance prompt supports summary and original preview modes', () => {
    const summaryPrompt = htmlEnhancePrompt({ ...explainBody, mode: 'summary' });
    const originalPrompt = htmlEnhancePrompt({ ...explainBody, mode: 'original' });

    expect(summaryPrompt).toContain('总结全文');
    expect(originalPrompt).toContain('不要改写原文主体');
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

  test('rejects oversized html enhance bodies without relying on content-length', async () => {
    resetAiGuardForTests();
    const app = createApp();
    const token = await deviceToken(app);
    const oversizedBody = JSON.stringify({
      mode: 'summary',
      context: {
        documentId: 'doc_1',
        title: 'Atlas',
        outline: '',
        excerpt: 'x'.repeat(70 * 1024),
      },
    });

    const response = await app.request('/v1/exports/html/enhance', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: oversizedBody,
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
