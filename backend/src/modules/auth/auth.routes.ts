import { Router } from "express";
import { register } from "./auth.controller";
import { registerRateLimiter } from "../../middlewares/rate-limit.middleware";

export const authRouter = Router();

authRouter.post("/register", registerRateLimiter, register);
