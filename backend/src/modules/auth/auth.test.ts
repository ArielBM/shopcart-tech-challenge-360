import assert from "node:assert/strict";
import { randomBytes, randomUUID } from "node:crypto";
import { once } from "node:events";
import { mock, test } from "node:test";
import express from "express";
import { SignJWT, decodeJwt } from "jose";
import {
  generateRefreshToken, hashRefreshToken, isRefreshToken, refreshCookieOptions,
} from "./auth.refresh";
import { isRole, type Role } from "./auth.types";

// Clave efímera de prueba: estos casos no necesitan .env ni conexión SQL.
process.env.JWT_SECRET_BASE64 = randomBytes(32).toString("base64");

void test("refresh aleatorio de 256 bits y hash SHA-256; formato canónico", () => {
  const first = generateRefreshToken();
  const second = generateRefreshToken();
  assert.notEqual(first, second);
  assert.equal(Buffer.from(first, "base64url").length, 32);
  assert.equal(isRefreshToken(first), true);
  assert.equal(hashRefreshToken(first).length, 32);
  assert.deepEqual(hashRefreshToken(first), hashRefreshToken(first));
  assert.notDeepEqual(hashRefreshToken(first), hashRefreshToken(second));
  for (const invalid of [undefined, null, "", "x".repeat(42), "x".repeat(44), "!".repeat(43)]) {
    assert.equal(isRefreshToken(invalid), false);
  }
  assert.equal(isRefreshToken("A".repeat(42) + "B"), false);
  assert.equal(refreshCookieOptions.httpOnly, true);
  assert.equal(refreshCookieOptions.sameSite, "lax");
  assert.equal(refreshCookieOptions.secure, process.env.NODE_ENV === "production");
  assert.equal(refreshCookieOptions.domain, undefined);
});

void test("JWT de 15 minutos, claims obligatorios y tres roles admitidos", async () => {
  const { createAccessToken, verifyAccessToken } = await import("./auth.tokens.js");
  const { authConfig } = await import("../../config/auth.config.js");
  const idFamilia = randomUUID();
  for (const rol of ["CLIENTE", "OPERADOR", "ADMINISTRADOR"] satisfies Role[]) {
    const token = await createAccessToken({ idUsuario: 1, idFamilia, rol });
    assert.deepEqual(await verifyAccessToken(token), { idUsuario: 1, idFamilia, rol });
    const payload = decodeJwt(token);
    assert.equal(typeof payload.exp, "number");
    assert.equal(typeof payload.iat, "number");
    assert.equal(Number(payload.exp) - Number(payload.iat), authConfig.accessTokenExpirationSeconds);
    assert.equal(authConfig.accessTokenExpirationSeconds, 900);
    await assert.rejects(verifyAccessToken(token + "x"));
  }

  const signed = (rol: unknown, sid: unknown = idFamilia) => new SignJWT({ rol, sid })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuer(authConfig.jwtIssuer).setAudience(authConfig.jwtAudience)
    .setSubject("1").setIssuedAt();

  for (const invalid of ["SUPERADMIN", "cliente", "", null, 1, undefined]) {
    assert.equal(isRole(invalid), false);
    const token = await signed(invalid).setExpirationTime("15m").sign(authConfig.jwtSecret);
    await assert.rejects(verifyAccessToken(token));
  }
  await assert.rejects(verifyAccessToken(await signed("CLIENTE").sign(authConfig.jwtSecret)));
  await assert.rejects(verifyAccessToken(await signed("CLIENTE").setExpirationTime(1).sign(authConfig.jwtSecret)));
  await assert.rejects(verifyAccessToken(await signed("CLIENTE").setIssuer("otro").setExpirationTime("15m").sign(authConfig.jwtSecret)));
  await assert.rejects(verifyAccessToken(await signed("CLIENTE").setAudience("otro").setExpirationTime("15m").sign(authConfig.jwtSecret)));
  for (const sid of [null, "invalido", 1, ""]) {
    await assert.rejects(verifyAccessToken(await signed("CLIENTE", sid).setExpirationTime("15m").sign(authConfig.jwtSecret)));
  }
  const withoutFamily = await new SignJWT({ rol: "CLIENTE" })
    .setProtectedHeader({ alg: "HS256" }).setSubject("1")
    .setIssuer(authConfig.jwtIssuer).setAudience(authConfig.jwtAudience)
    .setIssuedAt().setExpirationTime("15m").sign(authConfig.jwtSecret);
  await assert.rejects(verifyAccessToken(withoutFamily));
});

void test("errores de sesión 401, transitorios 503 e internos 500 sin filtrar mensajes", async () => {
  const { errorMiddleware } = await import("../../middlewares/error.middleware.js");
  const app = express();
  app.use(express.json());
  app.post("/json", (_req, res) => { res.status(200).end(); });
  app.get("/:number", (req, _res, next) => {
    next({ number: Number(req.params.number), message: "secreto-de-prueba" });
  });
  app.use(errorMiddleware);
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  const log = mock.method(console, "error", () => undefined);
  try {
    for (const [body, status] of [["{", 400], ["x".repeat(120000), 413]] as const) {
      const response: globalThis.Response = await fetch(`http://127.0.0.1:${String(address.port)}/json`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body,
      });
      assert.equal(response.status, status);
      await response.text();
    }
    for (const [code, status] of [
      [51020, 401], [51022, 401], [51023, 401], [51024, 401],
      [51026, 503], [1205, 503], [51021, 500], [51025, 500], [201, 500],
    ]) {
      const response: globalThis.Response = await fetch(`http://127.0.0.1:${String(address.port)}/${String(code)}`);
      assert.equal(response.status, status);
      assert.equal((await response.text()).includes("secreto-de-prueba"), false);
      if (status === 401) {
        assert.ok(response.headers.get("set-cookie")?.includes("Expires=Thu, 01 Jan 1970"));
      }
    }
    assert.equal(JSON.stringify(log.mock.calls).includes("secreto-de-prueba"), false);
  } finally {
    log.mock.restore();
    await new Promise<void>((resolve, reject) => {
      server.close(error => {
        if (error) reject(error);
        else resolve();
      });
    });
  }
});
