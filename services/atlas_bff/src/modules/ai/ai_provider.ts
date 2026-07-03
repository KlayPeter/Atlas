import OpenAI from 'openai';

import { env } from '../../shared/env';
import { AppError } from '../../shared/app_error';
import type { AskRequest, ExplainRequest, SummarizeRequest } from './contracts';
import { askPrompt, explainPrompt, summarizePrompt } from './prompts';

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
  generateStudyQuestions(request: any): Promise<any>;
  enhanceHtml(request: any): Promise<any>;
}

export interface AiConfig {
  apiKey?: string;
  baseUrl?: string;
  model?: string;
}

export function createAiProvider(config?: AiConfig): AiProvider {
  const apiKey = normalizeAiConfigValue(config?.apiKey) ?? env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new AppError(
      'AI_PROVIDER_NOT_CONFIGURED',
      'AI 未配置，请到设置里的 AI 模型配置填写 API Key、Base URL 和模型名称。',
      503,
    );
  }
  return new OpenAiProvider(
    apiKey,
    normalizeAiConfigValue(config?.baseUrl),
    normalizeAiConfigValue(config?.model),
  );
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

  async generateStudyQuestions(request: any): Promise<any> {
    const promptStr = require('./prompts').studyPrompt(request);
    const jsonStr = await this.completeJson(promptStr);
    try {
      const parsed = JSON.parse(jsonStr);
      return {
        difficulty: request.difficulty,
        questions: parsed.questions ?? [],
      };
    } catch (e) {
      return { difficulty: request.difficulty, questions: [] };
    }
  }

  async enhanceHtml(request: any): Promise<any> {
    const promptStr = require('./prompts').htmlEnhancePrompt(request);
    const jsonStr = await this.completeJson(promptStr);
    try {
      return JSON.parse(jsonStr);
    } catch (e) {
      return {
        title: request.context.title,
        lead: '',
        summary: '',
        sections: [],
        keyConcepts: [],
        questions: [],
      };
    }
  }

  private async complete(prompt: string) {
    const response = await this.client.chat.completions.create({
      model: this.model,
      messages: [{ role: 'user', content: prompt }],
    });
    return response.choices[0].message.content ?? '';
  }

  private async completeJson(prompt: string) {
    const response = await this.client.chat.completions.create({
      model: this.model,
      messages: [{ role: 'user', content: prompt }],
    });
    let content = response.choices[0].message.content ?? '{}';
    const match = content.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
    if (match) {
      content = match[1];
    }
    return content;
  }
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
