import { Router } from "express";
import { login, logout, refresh, register } from "./auth.controller";
import {
  registerRateLimiter,
  loginRateLimiter,
  refreshRateLimiter,
  logoutRateLimiter,
} from "../../middlewares/rate-limit.middleware";

export const authRouter = Router();

authRouter.post("/register", registerRateLimiter, register);
authRouter.post("/login", loginRateLimiter, login);
authRouter.post("/refresh", refreshRateLimiter, refresh);
authRouter.post("/logout", logoutRateLimiter, logout);
