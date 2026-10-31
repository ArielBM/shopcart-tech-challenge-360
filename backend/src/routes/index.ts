import { Router } from "express";
import { authRouter } from "../modules/auth/auth.routes";
import { categoriesRouter } from "../modules/catalog/categories.routes";

export const apiRouter = Router();

apiRouter.get("/health", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

apiRouter.use("/auth", authRouter);
apiRouter.use("/categories", categoriesRouter);
