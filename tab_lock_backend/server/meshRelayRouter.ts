import crypto from "crypto";
import { Router } from "express";
import { and, asc, eq, gt, inArray, lt } from "drizzle-orm";
import { getDb } from "./db";
import { meshRelayMessages, meshSessions } from "../drizzle/schema";

export const meshRelayRouter = Router();
const MAX_ENVELOPE_BYTES = 256 * 1024;
const SESSION_DAYS = 90;
const MESSAGE_MINUTES = 15;

function tokenHash(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function bearerToken(req: { headers: Record<string, unknown> }): string {
  const value = req.headers.authorization;
  if (typeof value !== "string") return "";
  return value.startsWith("Bearer ") ? value.substring(7).trim() : "";
}

function validId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9._:-]{1,128}$/.test(value);
}

async function authenticate(deviceId: string, peerId: string, token: string) {
  const db = await getDb();
  if (!db || !validId(deviceId) || !validId(peerId) || token.length < 32) return null;
  const rows = await db
    .select()
    .from(meshSessions)
    .where(
      and(
        eq(meshSessions.deviceId, deviceId),
        eq(meshSessions.peerId, peerId),
        eq(meshSessions.tokenHash, tokenHash(token)),
        eq(meshSessions.revoked, 0),
        gt(meshSessions.expiresAt, new Date()),
      ),
    )
    .limit(1);
  return rows[0] ?? null;
}

function envelopeString(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    try {
      return JSON.stringify(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

meshRelayRouter.post("/register", async (req, res) => {
  try {
    const { deviceId, peerId, token } = req.body ?? {};
    if (!validId(deviceId) || !validId(peerId) || typeof token !== "string" || token.length < 32) {
      return res.status(400).json({ success: false, error: "deviceId, peerId, and a strong session token are required." });
    }
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
    const hash = tokenHash(token);
    const existing = await db
      .select({ id: meshSessions.id })
      .from(meshSessions)
      .where(and(eq(meshSessions.deviceId, deviceId), eq(meshSessions.peerId, peerId)))
      .limit(1);
    if (existing.length > 0) {
      await db
        .update(meshSessions)
        .set({ tokenHash: hash, expiresAt, revoked: 0, updatedAt: new Date() })
        .where(eq(meshSessions.id, existing[0].id));
    } else {
      await db.insert(meshSessions).values({ deviceId, peerId, tokenHash: hash, expiresAt, revoked: 0 });
    }
    return res.json({ success: true, expiresAt });
  } catch (error) {
    console.error("[Mesh] register error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

meshRelayRouter.post("/send", async (req, res) => {
  try {
    const { fromDeviceId, toDeviceId, peerId } = req.body ?? {};
    const token = bearerToken(req);
    const envelope = envelopeString(req.body?.envelope);
    if (!validId(fromDeviceId) || !validId(toDeviceId) || peerId !== toDeviceId || !envelope) {
      return res.status(400).json({ success: false, error: "fromDeviceId, toDeviceId, matching peerId, and envelope are required." });
    }
    if (Buffer.byteLength(envelope, "utf8") > MAX_ENVELOPE_BYTES) {
      return res.status(413).json({ success: false, error: "Relay envelope is too large." });
    }
    const session = await authenticate(fromDeviceId, toDeviceId, token);
    if (!session) return res.status(401).json({ success: false, error: "Invalid or expired mesh session." });
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    const expiresAt = new Date(Date.now() + MESSAGE_MINUTES * 60 * 1000);
    const inserted = await db.insert(meshRelayMessages).values({
      fromDeviceId,
      toDeviceId,
      tokenHash: session.tokenHash,
      envelope,
      expiresAt,
      delivered: 0,
    });
    return res.json({ success: true, messageId: Number(inserted[0].insertId), expiresAt });
  } catch (error) {
    console.error("[Mesh] send error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

meshRelayRouter.get("/poll", async (req, res) => {
  try {
    const deviceId = typeof req.query.deviceId === "string" ? req.query.deviceId : "";
    const peerId = typeof req.query.peerId === "string" ? req.query.peerId : "";
    const token = bearerToken(req);
    const session = await authenticate(deviceId, peerId, token);
    if (!session) return res.status(401).json({ success: false, error: "Invalid or expired mesh session." });
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    await db.delete(meshRelayMessages).where(lt(meshRelayMessages.expiresAt, new Date()));
    const rows = await db
      .select()
      .from(meshRelayMessages)
      .where(
        and(
          eq(meshRelayMessages.toDeviceId, deviceId),
          eq(meshRelayMessages.fromDeviceId, peerId),
          eq(meshRelayMessages.tokenHash, session.tokenHash),
          eq(meshRelayMessages.delivered, 0),
          gt(meshRelayMessages.expiresAt, new Date()),
        ),
      )
      .orderBy(asc(meshRelayMessages.createdAt))
      .limit(50);
    return res.json({ success: true, messages: rows.map((row) => ({ id: row.id, envelope: row.envelope, createdAt: row.createdAt, expiresAt: row.expiresAt })) });
  } catch (error) {
    console.error("[Mesh] poll error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

meshRelayRouter.post("/ack", async (req, res) => {
  try {
    const { deviceId, peerId, messageIds } = req.body ?? {};
    const token = bearerToken(req);
    if (!validId(deviceId) || !validId(peerId) || !Array.isArray(messageIds) || messageIds.length > 50) {
      return res.status(400).json({ success: false, error: "deviceId, peerId, and at most 50 message IDs are required." });
    }
    const ids = messageIds.filter((value: unknown): value is number => typeof value === "number" && Number.isInteger(value) && value > 0);
    const session = await authenticate(deviceId, peerId, token);
    if (!session) return res.status(401).json({ success: false, error: "Invalid or expired mesh session." });
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    if (ids.length > 0) {
      await db.update(meshRelayMessages).set({ delivered: 1 }).where(
        and(
          inArray(meshRelayMessages.id, ids),
          eq(meshRelayMessages.toDeviceId, deviceId),
          eq(meshRelayMessages.fromDeviceId, peerId),
          eq(meshRelayMessages.tokenHash, session.tokenHash),
        ),
      );
    }
    return res.json({ success: true, acknowledged: ids.length });
  } catch (error) {
    console.error("[Mesh] ack error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

meshRelayRouter.post("/revoke", async (req, res) => {
  try {
    const { deviceId, peerId } = req.body ?? {};
    const token = bearerToken(req);
    const session = await authenticate(deviceId, peerId, token);
    if (!session) return res.status(401).json({ success: false, error: "Invalid or expired mesh session." });
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    await db.update(meshSessions).set({ revoked: 1, updatedAt: new Date() }).where(eq(meshSessions.id, session.id));
    return res.json({ success: true });
  } catch (error) {
    console.error("[Mesh] revoke error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});
