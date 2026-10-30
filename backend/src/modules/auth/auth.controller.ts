import type { Request, Response } from "express";
import { loginSchema, registerSchema } from "./auth.schemas";
import {
  refreshSession,
  registerClient,
  validateCredentials,
} from "./auth.service";
import { env } from "../../config/env";

export async function register(req: Request, res: Response): Promise<void> {
  const input = registerSchema.parse(req.body);
  const user = await registerClient(input);

  res.status(201).json({
    data: user,
  });
}

export async function login(req: Request, res: Response): Promise<void> {
  const input = loginSchema.parse(req.body);
  const result = await validateCredentials(input);

  if (!result) {
    res.status(401).json({
      error: {
        code: "INVALID_CREDENTIALS",
        message: "Correo o contraseña incorrectos.",
      },
    });
    return;
  }

  const { refreshToken, refreshTokenExpiresAt, ...responseData } = result;

  res.cookie("refreshToken", refreshToken, {
    httpOnly: true,
    secure: env.nodeEnv === "production",
    sameSite: "lax",
    path: "/api/v1/auth",
    expires: refreshTokenExpiresAt,
  });

  res.status(200).json({
    data: responseData,
  });
}

export async function refresh(req: Request, res: Response): Promise<void> {
  const cookies = req.cookies as Record<string, unknown> | undefined;

  const currentToken = cookies?.refreshToken;

  if (typeof currentToken !== "string" || !currentToken) {
    res.status(401).json({
      error: {
        code: "UNAUTHORIZED",
        message: "Sesión no válida.",
      },
    });
    return;
  }

  const result = await refreshSession(currentToken);

  const { refreshToken, refreshTokenExpiresAt, ...responseData } = result;

  res.cookie("refreshToken", refreshToken, {
    httpOnly: true,
    secure: env.nodeEnv === "production",
    sameSite: "lax",
    path: "/api/v1/auth",
    expires: refreshTokenExpiresAt,
  });

  res.status(200).json({
    data: responseData,
  });
}
