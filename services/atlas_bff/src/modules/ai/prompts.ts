import type { AskRequest, ExplainRequest, SummarizeRequest } from './contracts';

export function explainPrompt(request: ExplainRequest) {
  return [
    '你是 Atlas 的文档阅读助手。只基于当前文档上下文解释用户选中的内容。',
    '如果文档没有直接说明，请明确区分“文档依据”和“补充背景”。',
    `文档标题：${request.context.title}`,
    `文档大纲：\n${request.context.outline}`,
    `文档片段：\n${request.context.excerpt}`,
    `用户选中：${request.selectedText}`,
    '请输出简洁中文解释，并列出 2-4 个要点。',
  ].join('\n\n');
}

export function summarizePrompt(request: SummarizeRequest) {
  return [
    '你是 Atlas 的文档阅读助手。请基于当前文档片段做结构化总结。',
    `总结模式：${request.mode}`,
    `文档标题：${request.context.title}`,
    `文档大纲：\n${request.context.outline}`,
    `文档片段：\n${request.context.excerpt}`,
    '请输出 150-300 字摘要，并列出 3-6 个关键点。',
  ].join('\n\n');
}

export function askPrompt(request: AskRequest) {
  return [
    '你是 Atlas 的文档问答助手。回答必须优先基于当前文档。',
    '如果文档中没有答案，请说“文档中没有直接说明”，再给出必要背景。',
    `文档标题：${request.context.title}`,
    `文档大纲：\n${request.context.outline}`,
    `文档片段：\n${request.context.excerpt}`,
    `问题：${request.question}`,
  ].join('\n\n');
}
