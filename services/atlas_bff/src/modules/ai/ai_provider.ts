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

export interface AiConfig {
  apiKey?: string;
  baseUrl?: string;
  model?: string;
}

export function createAiProvider(config?: AiConfig): AiProvider {
  const apiKey = config?.apiKey || env.OPENAI_API_KEY;
  if (!apiKey) {
    return new MockAiProvider();
  }
  return new OpenAiProvider(apiKey, config?.baseUrl, config?.model);
}

class MockAiProvider implements AiProvider {
  async explain(request: ExplainRequest): Promise<ExplainResult> {
    return {
      title: request.selectedText,
      explanation: [
        `**是什么**：${request.selectedText} 是当前选中的概念或表述。`,
        `**在本文里**：它需要放回《${request.context.title}》的上下文理解，结合大纲和片段判断它服务于哪个问题。`,
        '**怎么做**：先定位相关章节，再把它转成可执行的问题、流程或决策点。',
      ].join('\n\n'),
      points: [
        '是什么',
        '在本文里',
        '怎么做',
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
