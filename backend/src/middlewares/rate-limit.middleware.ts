import { rateLimit } from "express-rate-limit";

export const registerRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: {
    error: {
      code: "RATE_LIMIT_EXCEEDED",
      message: "Demasiadas solicitudes. Intenta más tarde.",
    },
  },
});
