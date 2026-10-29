import { Router } from "express";
import { login, logout, refresh, register } from "./auth.controller";
import { protectAuthRequest } from "../../middlewares/csrf.middleware";
import {
  registerRateLimiter,
  loginRateLimiter,
} from "../../middlewares/rate-limit.middleware";

export const authRouter = Router();

authRouter.use((_req, res, next) => {
  res.set("Cache-Control", "no-store");
  next();
});

authRouter.post("/register", protectAuthRequest, registerRateLimiter, register);
authRouter.post("/login", protectAuthRequest, loginRateLimiter, login);
authRouter.post("/refresh", protectAuthRequest, refresh);
authRouter.post("/logout", protectAuthRequest, logout);
