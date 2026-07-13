import { z } from 'zod';

const envSchema = z
  .object({
    APP_ENV: z
      .enum(['development', 'test', 'production'])
      .default('development'),
    HOST: z.string().default('127.0.0.1'),
    PORT: z.coerce.number().int().positive().default(8787),
    OPENAI_API_KEY: z.string().optional(),
    OPENAI_MODEL: z.string().default('gpt-4.1-mini'),
    AI_PROVIDER_BASE_URL_ALLOWLIST: z.string().optional(),
    ATLAS_BFF_ACCESS_TOKEN: z.string().min(32).optional(),
    DATABASE_URL: z.string().optional(),
    REDIS_URL: z.string().optional(),
  })
  .superRefine((value, context) => {
    if (value.APP_ENV === 'production' && !value.OPENAI_API_KEY) {
      context.addIssue({
        code: 'custom',
        path: ['OPENAI_API_KEY'],
        message: 'OPENAI_API_KEY is required in production',
      });
    }
    if (value.APP_ENV === 'production' && !value.ATLAS_BFF_ACCESS_TOKEN) {
      context.addIssue({
        code: 'custom',
        path: ['ATLAS_BFF_ACCESS_TOKEN'],
        message: 'ATLAS_BFF_ACCESS_TOKEN is required in production',
      });
    }
  });

export const env = envSchema.parse(process.env);
