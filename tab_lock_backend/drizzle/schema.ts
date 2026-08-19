import { int, mysqlTable, text, timestamp, varchar } from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: int("id").autoincrement().primaryKey(),
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: varchar("role", { length: 32 }).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

/**
 * Stores active 6-digit OTP codes for account recovery.
 * Valid for 10 minutes from creation.
 */
export const otpCodes = mysqlTable("otp_codes", {
  id: int("id").autoincrement().primaryKey(),
  email: varchar("email", { length: 320 }).notNull(),
  codeHash: varchar("codeHash", { length: 255 }).notNull(),
  expiresAt: timestamp("expiresAt").notNull(),
  attempts: int("attempts").default(0).notNull(),
  used: int("used").default(0).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

/**
 * Audit logs for OTP requests and verification attempts.
 */
export const otpAuditLogs = mysqlTable("otp_audit_logs", {
  id: int("id").autoincrement().primaryKey(),
  emailMasked: varchar("emailMasked", { length: 320 }).notNull(),
  action: varchar("action", { length: 64 }).notNull(), // 'SEND_SUCCESS', 'SEND_RATE_LIMITED', 'VERIFY_SUCCESS', 'VERIFY_FAILED'
  ipAddress: varchar("ipAddress", { length: 64 }),
  status: varchar("status", { length: 32 }).notNull(), // 'SUCCESS' | 'FAILED' | 'BLOCKED'
  details: text("details"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;
export type OtpCode = typeof otpCodes.$inferSelect;
export const meshSessions = mysqlTable("mesh_sessions", {
  id: int("id").autoincrement().primaryKey(),
  deviceId: varchar("deviceId", { length: 128 }).notNull(),
  peerId: varchar("peerId", { length: 128 }).notNull(),
  tokenHash: varchar("tokenHash", { length: 128 }).notNull(),
  expiresAt: timestamp("expiresAt").notNull(),
  revoked: int("revoked").default(0).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export const meshRelayMessages = mysqlTable("mesh_relay_messages", {
  id: int("id").autoincrement().primaryKey(),
  fromDeviceId: varchar("fromDeviceId", { length: 128 }).notNull(),
  toDeviceId: varchar("toDeviceId", { length: 128 }).notNull(),
  tokenHash: varchar("tokenHash", { length: 128 }).notNull(),
  envelope: text("envelope").notNull(),
  expiresAt: timestamp("expiresAt").notNull(),
  delivered: int("delivered").default(0).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type OtpAuditLog = typeof otpAuditLogs.$inferSelect;
export type MeshSession = typeof meshSessions.$inferSelect;
export type MeshRelayMessage = typeof meshRelayMessages.$inferSelect;

/**
 * A policy group shared by one Android JARVIS controller and one or more
 * paired browser extensions.
 */
export const tabLockGroups = mysqlTable("tab_lock_groups", {
  id: int("id").autoincrement().primaryKey(),
  groupId: varchar("groupId", { length: 128 }).notNull().unique(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

/**
 * Browser/Android devices use bearer tokens whose hashes are stored here.
 * Pairing codes are one-time values and are never stored in plaintext.
 */
export const tabLockDevices = mysqlTable("tab_lock_devices", {
  id: int("id").autoincrement().primaryKey(),
  groupId: varchar("groupId", { length: 128 }).notNull(),
  deviceId: varchar("deviceId", { length: 128 }).notNull(),
  deviceType: varchar("deviceType", { length: 32 }).notNull(), // android | chrome
  deviceName: varchar("deviceName", { length: 160 }).notNull(),
  accessTokenHash: varchar("accessTokenHash", { length: 128 }).notNull(),
  pairCodeHash: varchar("pairCodeHash", { length: 128 }),
  paired: int("paired").default(0).notNull(),
  revoked: int("revoked").default(0).notNull(),
  expiresAt: timestamp("expiresAt").notNull(),
  lastSeenAt: timestamp("lastSeenAt"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

/**
 * Domain-level policies. `unlockVerifier` is a client-generated hash; the
 * server never receives or stores a plaintext password/PIN/passkey.
 */
export const tabLockPolicies = mysqlTable("tab_lock_policies", {
  id: int("id").autoincrement().primaryKey(),
  groupId: varchar("groupId", { length: 128 }).notNull(),
  domain: varchar("domain", { length: 253 }).notNull(),
  mode: varchar("mode", { length: 16 }).notNull(), // block | lock
  unlockSalt: varchar("unlockSalt", { length: 128 }),
  unlockVerifier: varchar("unlockVerifier", { length: 128 }),
  // AES-256-GCM envelope for the salt/verifier pair. Legacy plaintext columns
  // are retained only to migrate older policies during the next authenticated sync.
  unlockCredentialCiphertext: varchar("unlockCredentialCiphertext", { length: 1024 }),
  failurePage: varchar("failurePage", { length: 32 }).default("blocked").notNull(),
  relockOnRefresh: int("relockOnRefresh").default(1).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type TabLockGroup = typeof tabLockGroups.$inferSelect;
export type TabLockDevice = typeof tabLockDevices.$inferSelect;
export type TabLockPolicy = typeof tabLockPolicies.$inferSelect;
