import express from "express";
import type { Server } from "node:http";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { meshRelayRouter } from "./meshRelayRouter";

const app = express();
app.use(express.json({ limit: "1mb" }));
app.use("/api/mesh", meshRelayRouter);

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

describe("JARVIS mesh relay validation", () => {
  it("rejects weak registration tokens", async () => {
    const response = await jsonRequest("/api/mesh/register", {
      method: "POST",
      body: JSON.stringify({ deviceId: "device-a", peerId: "device-b", token: "short" }),
    });
    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({ success: false });
  });

  it("rejects oversized relay envelopes before authentication or storage", async () => {
    const response = await jsonRequest("/api/mesh/send", {
      method: "POST",
      headers: { authorization: `Bearer ${"t".repeat(64)}` },
      body: JSON.stringify({
        fromDeviceId: "device-a",
        toDeviceId: "device-b",
        peerId: "device-b",
        envelope: "x".repeat(256 * 1024 + 1),
      }),
    });
    expect(response.status).toBe(413);
  });

  it("rejects an invalid or expired poll session", async () => {
    const response = await jsonRequest("/api/mesh/poll?deviceId=device-a&peerId=device-b", {
      headers: { authorization: `Bearer ${"t".repeat(64)}` },
    });
    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toMatchObject({ error: "Invalid or expired mesh session." });
  });

  it("rejects acknowledgement batches larger than the protocol limit", async () => {
    const response = await jsonRequest("/api/mesh/ack", {
      method: "POST",
      body: JSON.stringify({ deviceId: "device-a", peerId: "device-b", messageIds: Array.from({ length: 51 }, (_, index) => index + 1) }),
    });
    expect(response.status).toBe(400);
  });
});
