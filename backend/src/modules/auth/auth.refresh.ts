import { createHash, randomBytes } from "node:crypto";

export function generateRefreshToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashRefreshToken(token: string): Buffer {
  return createHash("sha256").update(token, "utf-8").digest();
}
