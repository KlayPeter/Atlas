import { z } from 'zod';

const envSchema = z
  .object({
    APP_ENV: z
      .enum(['development', 'test', 'production'])
      .default('development'),
    PORT: z.coerce.number().int().positive().default(8787),
    OPENAI_API_KEY: z.string().optional(),
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
  });

export const env = envSchema.parse(process.env);
