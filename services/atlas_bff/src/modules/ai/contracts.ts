import { z } from 'zod';

export const documentContextSchema = z.object({
  documentId: z.string().min(1),
  title: z.string().min(1).max(240),
  outline: z.string().max(8000).default(''),
  excerpt: z.string().min(1).max(12000),
});

export const explainRequestSchema = z.object({
  selectedText: z.string().min(1).max(4000),
  context: documentContextSchema,
});

export const summarizeRequestSchema = z.object({
  mode: z.enum(['quick', 'structured']).default('structured'),
  context: documentContextSchema,
});

export const askRequestSchema = z.object({
  question: z.string().min(1).max(1000),
  context: documentContextSchema,
  stream: z.boolean().default(false),
});

export type DocumentContext = z.infer<typeof documentContextSchema>;
export type ExplainRequest = z.infer<typeof explainRequestSchema>;
export type SummarizeRequest = z.infer<typeof summarizeRequestSchema>;
export type AskRequest = z.infer<typeof askRequestSchema>;
