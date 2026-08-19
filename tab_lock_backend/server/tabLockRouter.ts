import crypto from "crypto";
import { Router } from "express";
import { and, eq, gt } from "drizzle-orm";
import { getDb } from "./db";
import { tabLockDevices, tabLockGroups, tabLockPolicies } from "../drizzle/schema";
import { decryptTabLockCredential, encryptTabLockCredential, tabLockEncryptionReady } from "./tabLockCrypto";

export const tabLockRouter = Router();

const SESSION_DAYS = 90;
const PAIRING_MINUTES = 30;
const VALID_MODES = new Set(["block", "lock"]);
const VALID_FAILURE_PAGES = new Set(["blocked", "not_found", "forbidden", "aw_snap"]);

function hash(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function randomToken(): string {
  return crypto.randomBytes(32).toString("base64url");
}

function randomGroupId(): string {
  return `jrv-${crypto.randomBytes(12).toString("hex")}`;
}

function randomPairingCode(): string {
  return String(crypto.randomInt(10000000, 100000000));
}

function bearerToken(req: { headers: Record<string, unknown> }): string {
  const value = req.headers.authorization;
  return typeof value === "string" && value.startsWith("Bearer ")
    ? value.substring(7).trim()
    : "";
}

function validId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9._:-]{1,128}$/.test(value);
}

function validName(value: unknown): value is string {
  return typeof value === "string" && value.trim().length >= 1 && value.trim().length <= 160;
}

export function normalizeDomain(value: unknown): string | null {
  if (typeof value !== "string") return null;
  let domain = value.trim().toLowerCase();
  domain = domain.replace(/^[a-z]+:\/\//, "").split("/")[0].split(":")[0];
  domain = domain.replace(/^www\./, "").replace(/\.$/, "");
  if (!domain || domain.length > 253 || domain.includes("..")) return null;
  if (!/^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(domain)) return null;
  return domain;
}

function validVerifier(value: unknown): value is string {
  return value === null || (typeof value === "string" && /^[a-f0-9]{64}$/i.test(value));
}

function validSalt(value: unknown): value is string {
  return value === null || (typeof value === "string" && /^[A-Za-z0-9_-]{16,128}$/.test(value));
}

async function findDevice(deviceId: string, token: string) {
  const db = await getDb();
  if (!db || !validId(deviceId) || token.length < 32) return null;
  const rows = await db
    .select()
    .from(tabLockDevices)
    .where(
      and(
        eq(tabLockDevices.deviceId, deviceId),
        eq(tabLockDevices.accessTokenHash, hash(token)),
        eq(tabLockDevices.revoked, 0),
        gt(tabLockDevices.expiresAt, new Date()),
      ),
    )
    .limit(1);
  return rows[0] ?? null;
}

export function deviceCanSync(device: { revoked: number; expiresAt: Date } | null, now = new Date()): boolean {
  return Boolean(device && device.revoked === 0 && device.expiresAt > now);
}

async function createGroup(db: NonNullable<Awaited<ReturnType<typeof getDb>>>, groupId: string) {
  await db.insert(tabLockGroups).values({ groupId });
}

function publicDevice(device: typeof tabLockDevices.$inferSelect) {
  return {
    deviceId: device.deviceId,
    deviceType: device.deviceType,
    deviceName: device.deviceName,
    paired: device.paired === 1,
    revoked: device.revoked === 1,
    lastSeenAt: device.lastSeenAt,
  };
}

async function syncPayload(db: NonNullable<Awaited<ReturnType<typeof getDb>>>, groupId: string) {
  const devices = await db.select().from(tabLockDevices).where(eq(tabLockDevices.groupId, groupId));
  const policies = await db.select().from(tabLockPolicies).where(eq(tabLockPolicies.groupId, groupId));
  const syncedPolicies = await Promise.all(policies.map(async (policy) => {
    let unlockSalt: string | null = null;
    let unlockVerifier: string | null = null;
    if (policy.unlockCredentialCiphertext) {
      const decrypted = decryptTabLockCredential(policy.unlockCredentialCiphertext);
      unlockSalt = decrypted.unlockSalt;
      unlockVerifier = decrypted.unlockVerifier;
    } else if (policy.unlockSalt && policy.unlockVerifier) {
      unlockSalt = policy.unlockSalt;
      unlockVerifier = policy.unlockVerifier;
      await db.update(tabLockPolicies).set({
        unlockSalt: null,
        unlockVerifier: null,
        unlockCredentialCiphertext: encryptTabLockCredential({ unlockSalt, unlockVerifier }),
        updatedAt: new Date(),
      }).where(eq(tabLockPolicies.id, policy.id));
    }
    return {
      id: policy.id,
      domain: policy.domain,
      mode: policy.mode,
      unlockSalt,
      unlockVerifier,
      failurePage: policy.failurePage,
      relockOnRefresh: policy.relockOnRefresh === 1,
      updatedAt: policy.updatedAt,
    };
  }));
  return {
    devices: devices.filter((device) => device.revoked === 0).map(publicDevice),
    policies: syncedPolicies,
  };
}

tabLockRouter.get("/crypto-status", (_req, res) => {
  const configured = tabLockEncryptionReady();
  return res.status(configured ? 200 : 503).json({ success: configured, configured, encryption: "AES-256-GCM" });
});

tabLockRouter.post("/register", async (req, res) => {
  try {
    const { deviceId, deviceType, deviceName } = req.body ?? {};
    if (!validId(deviceId) || !["android", "chrome"].includes(deviceType) || !validName(deviceName)) {
      return res.status(400).json({ success: false, error: "deviceId, deviceType, and deviceName are required." });
    }
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    const groupId = randomGroupId();
    await createGroup(db, groupId);
    const accessToken = randomToken();
    const pairingCode = randomPairingCode();
    const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
    const pairingExpiresAt = new Date(Date.now() + PAIRING_MINUTES * 60 * 1000);
    await db.insert(tabLockDevices).values({
      groupId,
      deviceId,
      deviceType,
      deviceName: deviceName.trim(),
      accessTokenHash: hash(accessToken),
      pairCodeHash: hash(pairingCode),
      paired: deviceType === "android" ? 1 : 0,
      revoked: 0,
      expiresAt,
      lastSeenAt: new Date(),
    });
    return res.json({ success: true, groupId, accessToken, pairingCode, pairingExpiresAt, expiresAt });
  } catch (error) {
    console.error("[TabLock] register error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

tabLockRouter.post("/pair", async (req, res) => {
  try {
    const { deviceId, deviceName, pairingCode } = req.body ?? {};
    const token = bearerToken(req);
    if (!validId(deviceId) || !validName(deviceName) || typeof pairingCode !== "string" || !/^\d{8}$/.test(pairingCode)) {
      return res.status(400).json({ success: false, error: "deviceId, deviceName, and an 8-digit pairing code are required." });
    }
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    const android = await findDevice(deviceId, token);
    if (android && android.deviceType !== "android") return res.status(403).json({ success: false, error: "Only an Android controller can pair browser devices." });
    const pending = await db
      .select()
      .from(tabLockDevices)
      .where(
        and(
          eq(tabLockDevices.pairCodeHash, hash(pairingCode)),
          eq(tabLockDevices.deviceType, "chrome"),
          eq(tabLockDevices.paired, 0),
          eq(tabLockDevices.revoked, 0),
          gt(tabLockDevices.expiresAt, new Date()),
        ),
      )
      .limit(1);
    const chrome = pending[0];
    if (!chrome) return res.status(401).json({ success: false, error: "Pairing code is invalid, expired, or already used." });

    let controller = android;
    if (!controller) {
      if (token.length < 32) return res.status(401).json({ success: false, error: "A strong Android bearer token is required." });
      const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
      await db.insert(tabLockDevices).values({
        groupId: chrome.groupId,
        deviceId,
        deviceType: "android",
        deviceName: deviceName.trim(),
        accessTokenHash: hash(token),
        paired: 1,
        revoked: 0,
        expiresAt,
        lastSeenAt: new Date(),
      });
      controller = (await findDevice(deviceId, token)) ?? null;
    } else if (controller.groupId !== chrome.groupId) {
      await db.update(tabLockDevices).set({ groupId: chrome.groupId, paired: 1, lastSeenAt: new Date(), updatedAt: new Date() }).where(eq(tabLockDevices.id, controller.id));
      controller = { ...controller, groupId: chrome.groupId, paired: 1, lastSeenAt: new Date() };
    }
    await db.update(tabLockDevices).set({ paired: 1, pairCodeHash: null, lastSeenAt: new Date(), updatedAt: new Date() }).where(eq(tabLockDevices.id, chrome.id));
    return res.json({ success: true, groupId: chrome.groupId, browserDevice: publicDevice({ ...chrome, paired: 1, pairCodeHash: null }), controller: controller ? publicDevice(controller) : null });
  } catch (error) {
    console.error("[TabLock] pair error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

tabLockRouter.get("/sync", async (req, res) => {
  try {
    const deviceId = typeof req.query.deviceId === "string" ? req.query.deviceId : "";
    const token = bearerToken(req);
    const device = await findDevice(deviceId, token);
    if (!device || !deviceCanSync(device)) return res.status(401).json({ success: false, error: "Invalid, revoked, or expired device token." });
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    await db.update(tabLockDevices).set({ lastSeenAt: new Date(), updatedAt: new Date() }).where(eq(tabLockDevices.id, device.id));
    return res.json({ success: true, groupId: device.groupId, ...(await syncPayload(db, device.groupId)) });
  } catch (error) {
    console.error("[TabLock] sync error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

tabLockRouter.post("/policy/upsert", async (req, res) => {
  try {
    const deviceId = typeof req.body?.deviceId === "string" ? req.body.deviceId : "";
    const token = bearerToken(req);
    const device = await findDevice(deviceId, token);
    if (!device || device.deviceType !== "android") return res.status(401).json({ success: false, error: "Only a paired Android controller can change policies." });
    const domain = normalizeDomain(req.body?.domain);
    const mode = req.body?.mode;
    const failurePage = req.body?.failurePage ?? "blocked";
    const relockOnRefresh = req.body?.relockOnRefresh === false ? 0 : 1;
    if (!domain || typeof mode !== "string" || !VALID_MODES.has(mode) || typeof failurePage !== "string" || !VALID_FAILURE_PAGES.has(failurePage) || !validSalt(req.body?.unlockSalt ?? null) || !validVerifier(req.body?.unlockVerifier ?? null)) {
      return res.status(400).json({ success: false, error: "Invalid domain, mode, failure page, salt, or verifier." });
    }
    if (mode === "lock" && (!req.body?.unlockSalt || !req.body?.unlockVerifier)) {
      return res.status(400).json({ success: false, error: "A lock policy requires a client-generated unlock salt and verifier." });
    }
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    const existing = await db.select().from(tabLockPolicies).where(and(eq(tabLockPolicies.groupId, device.groupId), eq(tabLockPolicies.domain, domain))).limit(1);
    const encryptedCredential = mode === "lock"
      ? encryptTabLockCredential({ unlockSalt: req.body.unlockSalt, unlockVerifier: req.body.unlockVerifier })
      : null;
    const values = {
      mode,
      unlockSalt: null,
      unlockVerifier: null,
      unlockCredentialCiphertext: encryptedCredential,
      failurePage,
      relockOnRefresh,
      updatedAt: new Date(),
    };
    if (existing[0]) await db.update(tabLockPolicies).set(values).where(eq(tabLockPolicies.id, existing[0].id));
    else await db.insert(tabLockPolicies).values({ groupId: device.groupId, domain, ...values });
    return res.json({ success: true, ...(await syncPayload(db, device.groupId)) });
  } catch (error) {
    console.error("[TabLock] policy upsert error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

tabLockRouter.post("/policy/delete", async (req, res) => {
  try {
    const deviceId = typeof req.body?.deviceId === "string" ? req.body.deviceId : "";
    const token = bearerToken(req);
    const device = await findDevice(deviceId, token);
    const domain = normalizeDomain(req.body?.domain);
    if (!device || device.deviceType !== "android" || !domain) return res.status(400).json({ success: false, error: "Valid controller and domain are required." });
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    await db.delete(tabLockPolicies).where(and(eq(tabLockPolicies.groupId, device.groupId), eq(tabLockPolicies.domain, domain)));
    return res.json({ success: true, ...(await syncPayload(db, device.groupId)) });
  } catch (error) {
    console.error("[TabLock] policy delete error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

tabLockRouter.post("/device/revoke", async (req, res) => {
  try {
    const deviceId = typeof req.body?.deviceId === "string" ? req.body.deviceId : "";
    const targetDeviceId = typeof req.body?.targetDeviceId === "string" ? req.body.targetDeviceId : "";
    const token = bearerToken(req);
    const controller = await findDevice(deviceId, token);
    if (!controller || controller.deviceType !== "android" || !validId(targetDeviceId)) return res.status(401).json({ success: false, error: "Only the paired Android controller can revoke a device." });
    const db = await getDb();
    if (!db) return res.status(503).json({ success: false, error: "Database not available." });
    await db.update(tabLockDevices).set({ revoked: 1, updatedAt: new Date() }).where(and(eq(tabLockDevices.groupId, controller.groupId), eq(tabLockDevices.deviceId, targetDeviceId)));
    return res.json({ success: true, ...(await syncPayload(db, controller.groupId)) });
  } catch (error) {
    console.error("[TabLock] revoke error", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});
