import express from "express";
import type { Server } from "node:http";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { decryptTabLockCredential, encryptTabLockCredential, tabLockEncryptionReady } from "./tabLockCrypto";
import { tabLockRouter } from "./tabLockRouter";

const app = express();
app.use(express.json());
app.use("/api/tab-lock", tabLockRouter);

let server: Server;
let baseUrl = "";

beforeAll(async () => {
  server = await new Promise<Server>((resolve) => {
    const instance = app.listen(0, "127.0.0.1", () => resolve(instance));
  });
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("Test server did not bind to a TCP port");
  baseUrl = `http://127.0.0.1:${address.port}`;
});

afterAll(async () => {
  await new Promise<void>((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
});

describe("Tab Lock encryption configuration", () => {
  it("validates the configured server key through the lightweight crypto status endpoint", async () => {
    const response = await fetch(`${baseUrl}/api/tab-lock/crypto-status`);
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      success: true,
      encryption: "AES-256-GCM",
      configured: true,
    });
    expect(tabLockEncryptionReady()).toBe(true);
  });

  it("encrypts the verifier material at rest and rejects a tampered envelope", () => {
    const material = { unlockSalt: "secure-salt-value", unlockVerifier: "a".repeat(64) };
    const envelope = encryptTabLockCredential(material);
    expect(envelope).not.toContain(material.unlockSalt);
    expect(envelope).not.toContain(material.unlockVerifier);
    expect(decryptTabLockCredential(envelope)).toEqual(material);
    expect(() => decryptTabLockCredential(`${envelope}x`)).toThrow();
  });
});
