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
  generateStudyQuestions(request: any): Promise<any>;
  enhanceHtml(request: any): Promise<any>;
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

  async generateStudyQuestions(request: any): Promise<any> {
    return {
      difficulty: request.difficulty,
      questions: [
        {
          question: `什么是《${request.context.title}》的核心概念？`,
          referenceAnswer: `根据开发 mock，这仅仅是一个占位回答，需要在配置 OPENAI_API_KEY 后才能生效。`,
        },
        {
          question: `请简述大纲中提到的关键步骤。`,
          referenceAnswer: `请结合实际文档内容进行作答。`,
        },
      ],
    };
  }

  async enhanceHtml(request: any): Promise<any> {
    return {
      title: request.context.title,
      lead: 'HTML enhance mock 导读内容',
      summary: '这是一段用于开发联调的 mock 摘要。',
      sections: [],
      keyConcepts: [
        { term: 'Mock', definition: '测试环境占位数据' }
      ],
      questions: [
        { q: '什么是 Mock？', a: '测试环境占位数据' }
      ],
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
    const response = await this.client.responses.create({
      model: env.OPENAI_MODEL,
      input: prompt,
    });
    return response.output_text;
  }

  private async completeJson(prompt: string) {
    const response = await this.client.chat.completions.create({
      model: env.OPENAI_MODEL,
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
    });
    return response.choices[0].message.content ?? '{}';
  }
}

function extractPoints(text: string) {
  return text
    .split('\n')
    .map((line) => line.replace(/^[-*•\d.、\s]+/, '').trim())
    .filter((line) => line.length > 0)
    .slice(0, 5);
}
