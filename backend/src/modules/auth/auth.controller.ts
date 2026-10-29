import type { Request, Response } from "express";
import { loginSchema, registerSchema } from "./auth.schemas";
import {
  refreshSession,
  registerClient,
  validateCredentials,
  logoutSession,
} from "./auth.service";
import {
  isRefreshToken, refreshCookieName, refreshCookieOptions,
} from "./auth.refresh";

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

  res.cookie(refreshCookieName, refreshToken, {
    ...refreshCookieOptions,
    expires: refreshTokenExpiresAt,
  });

  res.status(200).json({
    data: responseData,
  });
}

export async function refresh(req: Request, res: Response): Promise<void> {
  const cookies = req.cookies as Record<string, unknown> | undefined;

  const currentToken = cookies?.refreshToken;

  if (!isRefreshToken(currentToken)) {
    res.clearCookie(refreshCookieName, refreshCookieOptions);
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

  res.cookie(refreshCookieName, refreshToken, {
    ...refreshCookieOptions,
    expires: refreshTokenExpiresAt,
  });

  res.status(200).json({
    data: responseData,
  });
}

export async function logout(req: Request, res: Response): Promise<void> {
  const cookies = req.cookies as Record<string, unknown> | undefined;
  const token = cookies?.refreshToken;
  if (isRefreshToken(token)) await logoutSession(token);
  res.clearCookie(refreshCookieName, refreshCookieOptions);
  res.status(204).end();
}
