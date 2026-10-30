import { Router } from "express";
import { login, refresh, register } from "./auth.controller";
import {
  registerRateLimiter,
  loginRateLimiter,
} from "../../middlewares/rate-limit.middleware";

export const authRouter = Router();

authRouter.post("/register", registerRateLimiter, register);
authRouter.post("/login", loginRateLimiter, login);
authRouter.post("/refresh", refresh);
