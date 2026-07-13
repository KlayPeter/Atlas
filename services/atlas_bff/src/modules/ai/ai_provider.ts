import OpenAI from 'openai';
import { isIP } from 'node:net';
import { z } from 'zod';

import { env } from '../../shared/env';
import { AppError } from '../../shared/app_error';
import {
  generatedStudyQuestionsSchema,
  htmlEnhanceResultSchema,
  type AskRequest,
  type ExplainRequest,
  type HtmlEnhanceRequest,
  type HtmlEnhanceResult,
  type StudyRequest,
  type SummarizeRequest,
} from './contracts';
import {
  askPrompt,
  explainPrompt,
  htmlEnhancePrompt,
  studyPrompt,
  summarizePrompt,
} from './prompts';

export type ExplainResult = {
  title: string;
  explanation: string;
  points: string[];
};

export type SummaryResult = {
  title: string;
  summary: string;
  keyPoints: string[];
};

export type AskResult = {
  answer: string;
  references: string[];
};

export interface AiProvider {
  explain(request: ExplainRequest): Promise<ExplainResult>;
  summarize(request: SummarizeRequest): Promise<SummaryResult>;
  ask(request: AskRequest): Promise<AskResult>;
  generateStudyQuestions(request: StudyRequest): Promise<{
    difficulty: StudyRequest['difficulty'];
    questions: Array<{ question: string; referenceAnswer: string }>;
  }>;
  enhanceHtml(request: HtmlEnhanceRequest): Promise<HtmlEnhanceResult>;
}

export interface AiConfig {
  apiKey?: string;
  baseUrl?: string;
  model?: string;
}

export function createAiProvider(config?: AiConfig): AiProvider {
  const clientApiKey = normalizeAiConfigValue(config?.apiKey);
  const requestedBaseUrl = normalizeAiConfigValue(config?.baseUrl);
  const requestedModel = normalizeAiConfigValue(config?.model);

  if (!clientApiKey && (requestedBaseUrl || requestedModel)) {
    throw new AppError(
      'INVALID_AI_PROVIDER_CONFIG',
      'Base URL and model overrides require a client-owned API key.',
      400,
    );
  }

  const apiKey = clientApiKey ?? env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new AppError(
      'AI_PROVIDER_NOT_CONFIGURED',
      'AI 未配置，请到设置里的 AI 模型配置填写 API Key、Base URL 和模型名称。',
      503,
    );
  }
  return new OpenAiProvider(
    apiKey,
    requestedBaseUrl ? validateProviderBaseUrl(requestedBaseUrl) : undefined,
    requestedModel,
  );
}

function validateProviderBaseUrl(value: string) {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new AppError(
      'INVALID_AI_PROVIDER_CONFIG',
      'AI provider Base URL is invalid.',
      400,
    );
  }

  if (url.username || url.password || url.search || url.hash) {
    throw new AppError(
      'INVALID_AI_PROVIDER_CONFIG',
      'AI provider Base URL cannot contain credentials, query, or fragment.',
      400,
    );
  }

  const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, '');
  const loopback = hostname === 'localhost' || hostname === '::1' || hostname.startsWith('127.');
  if (url.protocol !== 'https:' && !(env.APP_ENV !== 'production' && loopback && url.protocol === 'http:')) {
    throw new AppError(
      'INVALID_AI_PROVIDER_CONFIG',
      'AI provider Base URL must use HTTPS; HTTP is only allowed for local development.',
      400,
    );
  }

  if (!loopback && isPrivateHostname(hostname)) {
    throw new AppError(
      'INVALID_AI_PROVIDER_CONFIG',
      'AI provider Base URL cannot target a private network.',
      400,
    );
  }

  if (env.APP_ENV === 'production') {
    const allowedOrigins = new Set(
      (env.AI_PROVIDER_BASE_URL_ALLOWLIST ?? '')
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean)
        .map((item) => new URL(item).origin),
    );
    if (!allowedOrigins.has(url.origin)) {
      throw new AppError(
        'INVALID_AI_PROVIDER_CONFIG',
        'AI provider Base URL is not allowed by this Atlas BFF.',
        400,
      );
    }
  }

  return url.toString().replace(/\/$/, '');
}

function isPrivateHostname(hostname: string) {
  if (
    hostname.endsWith('.local') ||
    hostname.endsWith('.internal') ||
    hostname === 'metadata.google.internal'
  ) {
    return true;
  }

  const ipVersion = isIP(hostname);
  if (ipVersion === 4) {
    const [first, second] = hostname.split('.').map(Number);
    return (
      first === 0 ||
      first === 10 ||
      first === 127 ||
      (first === 100 && second >= 64 && second <= 127) ||
      (first === 169 && second === 254) ||
      (first === 172 && second >= 16 && second <= 31) ||
      (first === 192 && second === 168) ||
      first >= 224
    );
  }
  if (ipVersion === 6) {
    return hostname === '::' || hostname === '::1' || /^(fc|fd|fe8|fe9|fea|feb)/i.test(hostname);
  }
  return false;
}

class OpenAiProvider implements AiProvider {
  private readonly client: OpenAI;
  private readonly model: string;

  constructor(apiKey: string, baseUrl?: string, model?: string) {
    this.client = new OpenAI({ 
      apiKey,
      baseURL: baseUrl || undefined,
    });
    this.model = model || env.OPENAI_MODEL;
  }

  async explain(request: ExplainRequest): Promise<ExplainResult> {
    const text = await this.complete(explainPrompt(request));
    return {
      title: request.selectedText,
      explanation: text,
      points: extractPoints(text),
    };
  }

  async summarize(request: SummarizeRequest): Promise<SummaryResult> {
    const text = await this.complete(summarizePrompt(request));
    return {
      title: `《${request.context.title}》总结`,
      summary: text,
      keyPoints: extractPoints(text),
    };
  }

  async ask(request: AskRequest): Promise<AskResult> {
    const answer = await this.complete(askPrompt(request));
    return {
      answer,
      references: request.context.outline
        .split('\n')
        .filter(Boolean)
        .slice(0, 3),
    };
  }

  async generateStudyQuestions(request: StudyRequest) {
    const parsed = await this.completeJson(
      studyPrompt(request),
      generatedStudyQuestionsSchema,
    );
    return { difficulty: request.difficulty, questions: parsed.questions };
  }

  async enhanceHtml(request: HtmlEnhanceRequest): Promise<HtmlEnhanceResult> {
    return this.completeJson(htmlEnhancePrompt(request), htmlEnhanceResultSchema);
  }

  private async complete(prompt: string) {
    const response = await this.client.chat.completions.create({
      model: this.model,
      messages: [{ role: 'user', content: prompt }],
    });
    return response.choices[0].message.content ?? '';
  }

  private async completeJson<T>(prompt: string, schema: z.ZodType<T>) {
    const response = await this.client.chat.completions.create({
      model: this.model,
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
    });
    return parseStructuredResponse(
      response.choices[0].message.content ?? '',
      schema,
    );
  }
}

export function parseStructuredResponse<T>(content: string, schema: z.ZodType<T>) {
  const match = content.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
  const candidate = (match?.[1] ?? content).trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(candidate);
  } catch {
    throw new AppError(
      'AI_INVALID_RESPONSE',
      'AI 返回的结构化内容不是合法 JSON，请重试或更换模型。',
      502,
    );
  }

  const result = schema.safeParse(parsed);
  if (!result.success) {
    throw new AppError(
      'AI_INVALID_RESPONSE',
      'AI 返回的结构化内容缺少必要字段，请重试或更换模型。',
      502,
      result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
      })),
    );
  }
  return result.data;
}

function extractPoints(text: string) {
  return text
    .split('\n')
    .map((line) => line.replace(/^[-*•\d.、\s]+/, '').trim())
    .filter((line) => line.length > 0)
    .slice(0, 5);
}

function normalizeAiConfigValue(value?: string) {
  const normalized = value?.trim();
  if (!normalized) {
    return undefined;
  }

  const lowered = normalized.toLowerCase();
  const placeholderValues = new Set([
    'xxx',
    'your-api-key',
    'your_api_key',
    'changeme',
    'change-me',
  ]);
  if (placeholderValues.has(lowered)) {
    return undefined;
  }

  return normalized;
}
