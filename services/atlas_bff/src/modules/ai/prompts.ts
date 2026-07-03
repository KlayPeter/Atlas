import type { AskRequest, ExplainRequest, SummarizeRequest } from './contracts';

export function explainPrompt(request: ExplainRequest) {
  return [
    '你是 Atlas 的文档阅读助手，目标是帮用户更好地理解文章。',
    '请只解释用户选中的内容，不要泛泛总结整篇文档。',
    '如果选中内容是名词、术语或短语：先说明它本身是什么意思，再说明它在本文中指什么。',
    '如果选中内容是一句话：解释这句话在当前段落和整篇文档里的意思、作用或暗含判断。',
    '如果必须补充背景，请明确说这是补充背景；不要编造文档没有表达的结论。',
    '请用简洁自然的中文 Markdown 输出，适合放在阅读浮窗中，80-180 字。不使用固定编号模板，不输出“怎么做”行动建议，除非原文明确在给步骤。',
    `文档标题：${request.context.title}`,
    `文档大纲：\n${request.context.outline}`,
    `文档片段：\n${request.context.excerpt}`,
    `用户选中：${request.selectedText}`,
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
    '你是 Atlas 的文档网页设计与整理助手。你需要为当前文档生成适合 HTML 预览的结构化内容。',
    `目标模式：${request.mode} (summary 表示总结全文；original 表示保留原文主线但优化导读、结构和阅读提示)`,
    request.mode === 'summary'
      ? 'summary 模式：重点给出清晰导读、全文摘要、章节要点、核心概念和读者可以继续追问的问题。'
      : 'original 模式：不要改写原文主体，重点生成友好的网页标题、导读、章节阅读提示和核心概念，帮助原文展示更清楚。',
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
