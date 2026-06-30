type ErrorBody = {
  code: string;
  message: string;
  details?: unknown;
};

export function successResponse<T>(data: T) {
  return {
    ok: true,
    data,
  } as const;
}

export function errorResponse(error: ErrorBody) {
  return {
    ok: false,
    error,
  } as const;
}
