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

export const studyRequestSchema = z.object({
  difficulty: z.enum(['basic', 'advanced', 'challenge']).default('basic'),
  context: documentContextSchema,
});

export const htmlEnhanceRequestSchema = z.object({
  mode: z.enum(['summary', 'original']).default('summary'),
  context: documentContextSchema,
});

export const generatedStudyQuestionsSchema = z
  .object({
    questions: z
      .array(
        z
          .object({
            question: z.string().min(1).max(500),
            referenceAnswer: z.string().min(1).max(2000),
          })
          .strict(),
      )
      .min(3)
      .max(5),
  })
  .strict();

export const htmlEnhanceResultSchema = z
  .object({
    title: z.string().min(1).max(240),
    lead: z.string().min(1).max(800),
    summary: z.string().min(1).max(4000),
    sections: z
      .array(
        z
          .object({
            title: z.string().min(1).max(240),
            content: z.string().min(1).max(2000),
          })
          .strict(),
      )
      .max(20),
    keyConcepts: z
      .array(
        z
          .object({
            term: z.string().min(1).max(120),
            definition: z.string().min(1).max(1000),
          })
          .strict(),
      )
      .max(20),
    questions: z
      .array(
        z
          .object({
            q: z.string().min(1).max(500),
            a: z.string().min(1).max(2000),
          })
          .strict(),
      )
      .max(10),
  })
  .strict();

export type DocumentContext = z.infer<typeof documentContextSchema>;
export type ExplainRequest = z.infer<typeof explainRequestSchema>;
export type SummarizeRequest = z.infer<typeof summarizeRequestSchema>;
export type AskRequest = z.infer<typeof askRequestSchema>;
export type StudyRequest = z.infer<typeof studyRequestSchema>;
export type HtmlEnhanceRequest = z.infer<typeof htmlEnhanceRequestSchema>;
export type GeneratedStudyQuestions = z.infer<
  typeof generatedStudyQuestionsSchema
>;
export type HtmlEnhanceResult = z.infer<typeof htmlEnhanceResultSchema>;
