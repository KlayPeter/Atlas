import OpenAI from 'openai';

import { env } from '../../shared/env';
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
}

export function createAiProvider(): AiProvider {
  if (!env.OPENAI_API_KEY) {
    return new MockAiProvider();
  }
  return new OpenAiProvider(env.OPENAI_API_KEY);
}

class MockAiProvider implements AiProvider {
  async explain(request: ExplainRequest): Promise<ExplainResult> {
    return {
      title: '基于文档的解释',
      explanation: `“${request.selectedText}”在《${request.context.title}》中需要结合当前章节理解。开发环境未配置 OPENAI_API_KEY，因此这里返回可联调的本地解释。`,
      points: [
        '解释请求已包含文档标题、大纲、片段和选中文本。',
        '后端没有记录原文，只返回统一响应结构。',
        '配置 OPENAI_API_KEY 后会切换为真实模型调用。',
      ],
    };
  }

  async summarize(request: SummarizeRequest): Promise<SummaryResult> {
    const firstLine = request.context.excerpt.split('\n').find(Boolean) ?? '';
    return {
      title: `《${request.context.title}》总结`,
      summary: `这份文档围绕“${firstLine.slice(0, 80)}”展开。当前为开发 mock，总结接口、字段和错误处理已经可供 Flutter 联调。`,
      keyPoints: ['保留本地阅读优先', 'AI 围绕当前文档', '上下文长度受到限制'],
    };
  }

  async ask(request: AskRequest): Promise<AskResult> {
    return {
      answer: `问题“${request.question}”已收到。开发 mock 会基于《${request.context.title}》返回占位答案；配置模型后将按文档上下文回答。`,
      references: ['当前文档片段', '当前文档大纲'],
    };
  }
}

class OpenAiProvider implements AiProvider {
  private readonly client: OpenAI;

  constructor(apiKey: string) {
    this.client = new OpenAI({ apiKey });
  }

  async explain(request: ExplainRequest): Promise<ExplainResult> {
    const text = await this.complete(explainPrompt(request));
    return {
      title: '基于文档的解释',
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

  private async complete(prompt: string) {
    const response = await this.client.responses.create({
      model: env.OPENAI_MODEL,
      input: prompt,
    });
    return response.output_text;
  }
}

function extractPoints(text: string) {
  return text
    .split('\n')
    .map((line) => line.replace(/^[-*•\d.、\s]+/, '').trim())
    .filter((line) => line.length > 0)
    .slice(0, 5);
}
