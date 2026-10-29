import { createHash, randomBytes } from "node:crypto";
import type { CookieOptions } from "express";

export const refreshCookieName = "refreshToken";
export const refreshCookieOptions: CookieOptions = {
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax",
  path: "/api/v1/auth",
};

export function isRefreshToken(token: unknown): token is string {
  return typeof token === "string" && /^[A-Za-z0-9_-]{43}$/.test(token)
    && Buffer.from(token, "base64url").toString("base64url") === token;
}

export function generateRefreshToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashRefreshToken(token: string): Buffer {
  return createHash("sha256").update(token, "utf-8").digest();
}
