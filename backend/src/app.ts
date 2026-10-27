import { env } from "./config/env";

import express from "express";
import cors from "cors";
import helmet from "helmet";

export const app = express();

app.use(helmet());
app.use(cors({ origin: env.corsOrigin }));
app.use(express.json());

app.get("/api/v1/health", (_req, res) => {
  res.status(200).json({ status: "ok" });
});
