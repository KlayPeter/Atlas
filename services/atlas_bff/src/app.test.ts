import { describe, expect, test } from 'bun:test';

import { createApp } from './app';
import { resetAiGuardForTests } from './middleware/ai_guard';
import { createDeviceToken, resetAuthForTests } from './middleware/auth';
import {
  explainRequestSchema,
  htmlEnhanceResultSchema,
} from './modules/ai/contracts';
import { parseStructuredResponse } from './modules/ai/ai_provider';
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

  test('rejects expired device tokens', async () => {
    resetAuthForTests();
    const app = createApp();
    const thirtyOneDaysAgo = Date.now() - 31 * 24 * 60 * 60 * 1000;
    const { token } = createDeviceToken(thirtyOneDaysAgo);

    const response = await app.request('/v1/ai/explain', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(explainBody),
    });

    expect(response.status).toBe(401);
    expect((await response.json()).error.code).toBe('UNAUTHORIZED');
  });

  test('protects device enrollment when bff access token is configured', async () => {
    const app = createApp({ accessToken: 'a'.repeat(32) });

    const rejected = await app.request('/v1/auth/device', { method: 'POST' });
    const accepted = await app.request('/v1/auth/device', {
      method: 'POST',
      headers: { 'x-atlas-access-token': 'a'.repeat(32) },
    });

    expect(rejected.status).toBe(401);
    expect((await rejected.json()).error.code).toBe('UNAUTHORIZED');
    expect(accepted.status).toBe(200);
  });

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
    const prompt = explainPrompt({ ...explainBody, mode: 'explain' });

    expect(prompt).toContain('Markdown');
    expect(prompt).toContain('通用含义');
    expect(prompt).toContain('原文也是这样的意思');
    expect(prompt).toContain('中文翻译');
  });

  test('selection translation has a dedicated prompt and defaults safely', () => {
    const defaultRequest = explainRequestSchema.parse(explainBody);
    const prompt = explainPrompt({ ...explainBody, mode: 'translate' });

    expect(defaultRequest.mode).toBe('explain');
    expect(prompt).toContain('划词翻译助手');
    expect(prompt).toContain('中文翻译成自然英文');
    expect(prompt).toContain('其他语言翻译成自然中文');
    expect(prompt).not.toContain('通用含义');
  });

  test('html enhance prompt supports readable and original preview modes', () => {
    const summaryPrompt = htmlEnhancePrompt({ ...explainBody, mode: 'readable' });
    const originalPrompt = htmlEnhancePrompt({ ...explainBody, mode: 'original' });

    expect(summaryPrompt).toContain('易读版正文');
    expect(summaryPrompt).toContain('不得增加原文没有的事实');
    expect(summaryPrompt).toContain('先识别原文已有的主题边界');
    expect(summaryPrompt).toContain('每段只推进一个主题');
    expect(summaryPrompt).toContain('若原文已足够清楚');
    expect(summaryPrompt).toContain('完成前按读者视角自检');
    expect(originalPrompt).toContain('逐字保留');
    expect(summaryPrompt).toContain('不可信数据');
  });

  test('validates structured html enhancement responses', () => {
    const result = parseStructuredResponse(
      JSON.stringify({
        title: 'Atlas',
        lead: '导读',
        summary: '摘要',
        rewrittenMarkdown: '# Atlas\n\n易读正文',
        sections: [],
        keyConcepts: [],
        questions: [],
      }),
      htmlEnhanceResultSchema,
    );

    expect(result.title).toBe('Atlas');
    expect(() =>
      parseStructuredResponse('{"title":"Atlas"}', htmlEnhanceResultSchema),
    ).toThrow('结构化内容缺少必要字段');
    expect(() =>
      parseStructuredResponse('not-json', htmlEnhanceResultSchema),
    ).toThrow('不是合法 JSON');
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
