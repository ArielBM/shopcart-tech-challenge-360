import { rateLimit } from "express-rate-limit";

const rateLimitOptions = {
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: "draft-8" as const,
  legacyHeaders: false,
  message: {
    error: {
      code: "RATE_LIMIT_EXCEEDED",
      message: "Demasiadas solicitudes. Intenta más tarde.",
    },
  },
};

export const registerRateLimiter = rateLimit(rateLimitOptions);
export const loginRateLimiter = rateLimit(rateLimitOptions);
