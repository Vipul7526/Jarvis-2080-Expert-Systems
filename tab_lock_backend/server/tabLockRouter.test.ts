import express from "express";
import type { Server } from "node:http";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { normalizeDomain, tabLockRouter } from "./tabLockRouter";

const app = express();
app.use(express.json({ limit: "1mb" }));
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

async function jsonRequest(path: string, init: RequestInit = {}) {
  return fetch(`${baseUrl}${path}`, {
    ...init,
    headers: { "content-type": "application/json", ...(init.headers ?? {}) },
  });
}

describe("JARVIS Tab Lock validation", () => {
  it("normalizes protocol, www, paths, and trailing dots", () => {
    expect(normalizeDomain("https://www.Example.com/path/to/page")).toBe("example.com");
    expect(normalizeDomain("example.com.")).toBe("example.com");
  });

  it("rejects invalid domains", () => {
    expect(normalizeDomain("localhost")).toBeNull();
    expect(normalizeDomain("example..com")).toBeNull();
    expect(normalizeDomain("https://example.com:443/path")).toBe("example.com");
  });

  it("rejects pairing codes that are not exactly eight digits", async () => {
    const response = await jsonRequest("/api/tab-lock/pair", {
      method: "POST",
      headers: { authorization: `Bearer ${"t".repeat(64)}` },
      body: JSON.stringify({ deviceId: "android-test", deviceName: "Test phone", pairingCode: "123456" }),
    });
    expect(response.status).toBe(400);
  });

  it("rejects policy mutation without a live controller token", async () => {
    const response = await jsonRequest("/api/tab-lock/policy/upsert", {
      method: "POST",
      headers: { authorization: `Bearer ${"t".repeat(64)}` },
      body: JSON.stringify({ deviceId: "android-test", domain: "example.com", mode: "block" }),
    });
    expect(response.status).toBe(401);
  });
});
