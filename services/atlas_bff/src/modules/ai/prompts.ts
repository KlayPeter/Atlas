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

export function studyPrompt(request: any) {
  return [
    '你是 Atlas 的学习助手。基于当前文档片段，生成 3-5 道适合复习的题目。',
    `当前难度模式：${request.difficulty}`,
    '要求返回合法的 JSON 对象，包含一个 `questions` 数组，每个元素包含 `question` 和 `referenceAnswer`。',
    `文档标题：${request.context.title}`,
    `文档片段：\n${request.context.excerpt}`,
  ].join('\n\n');
}

export function htmlEnhancePrompt(request: any) {
  return [
    '你是 Atlas 的文档整理助手。你需要对当前文档片段进行结构化处理。',
    `目标模式：${request.mode} (summary 或 study)`,
    '要求返回合法的 JSON 对象，必须包含：',
    '- `title`: 建议的网页标题',
    '- `lead`: 一两句话导读',
    '- `summary`: 整体摘要',
    '- `sections`: 数组，每个包含 `title` 和 `content`',
    '- `keyConcepts`: 数组，每个包含 `term` 和 `definition`',
    '- `questions`: 数组，每个包含 `q` 和 `a`',
    `原文档标题：${request.context.title}`,
    `原文档片段：\n${request.context.excerpt}`,
  ].join('\n\n');
}

