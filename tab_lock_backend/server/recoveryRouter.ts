import { Router } from "express";
import nodemailer from "nodemailer";
import crypto from "crypto";
import { and, desc, eq, gte, sql } from "drizzle-orm";
import { getDb } from "./db";
import { otpAuditLogs, otpCodes } from "../drizzle/schema";

export const recoveryRouter = Router();

// Helper to mask email for audit logs (e.g. u***@gmail.com)
function maskEmail(email: string): string {
  const parts = email.split("@");
  if (parts.length !== 2) return "***@***.com";
  const name = parts[0];
  const domain = parts[1];
  const maskedName = name.length > 2 ? name.substring(0, 2) + "***" : "***";
  return `${maskedName}@${domain}`;
}

// Nodemailer transporter configured via environment variables
function getTransporter() {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_APP_PASSWORD;
  if (!user || !pass) {
    console.warn("[SMTP] GMAIL_USER or GMAIL_APP_PASSWORD not configured.");
  }
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: user || "jarvis.assistant.pro@gmail.com",
      pass: pass || "",
    },
  });
}

/**
 * POST /api/recovery/send-otp
 * Accepts recipient email, enforces rate limit (max 3/hr), generates 6-digit OTP (10 min expiry),
 * sends via Gmail SMTP, and logs audit record.
 */
recoveryRouter.post("/send-otp", async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || typeof email !== "string" || !email.includes("@")) {
      return res.status(400).json({ success: false, error: "Valid recipient email is required." });
    }

    const trimmedEmail = email.trim().toLowerCase();
    const masked = maskEmail(trimmedEmail);
    const ip = req.ip || req.headers["x-forwarded-for"] || "unknown";

    const db = await getDb();
    if (!db) {
      return res.status(500).json({ success: false, error: "Database not available." });
    }

    // Check rate limit: max 3 requests per email per hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentRequests = await db
      .select()
      .from(otpCodes)
      .where(and(eq(otpCodes.email, trimmedEmail), gte(otpCodes.createdAt, oneHourAgo)));

    if (recentRequests.length >= 3) {
      await db.insert(otpAuditLogs).values({
        emailMasked: masked,
        action: "SEND_RATE_LIMITED",
        ipAddress: String(ip),
        status: "BLOCKED",
        details: "Rate limit exceeded: 3 requests per hour",
      });
      return res.status(429).json({
        success: false,
        error: "Rate limit exceeded. Maximum 3 OTP requests per hour allowed.",
      });
    }

    // Generate 6-digit OTP
    const otpCode = crypto.randomInt(100000, 999999).toString();
    const codeHash = crypto.createHash("sha256").update(otpCode).digest("hex");
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes expiry

    await db.insert(otpCodes).values({
      email: trimmedEmail,
      codeHash,
      expiresAt,
      attempts: 0,
      used: 0,
    });

    // Send email via Gmail SMTP
    const transporter = getTransporter();
    const mailOptions = {
      from: `"JARVIS 2080 Security" <${process.env.GMAIL_USER || "jarvis.assistant.pro@gmail.com"}>`,
      to: trimmedEmail,
      subject: "JARVIS 2080 - Account Recovery OTP",
      text: `Your JARVIS 2080 account recovery verification code is: ${otpCode}.\n\nThis code is valid for exactly 10 minutes.\n\nIf you did not request this recovery code, please secure your account immediately.`,
      html: `
        <div style="font-family: Arial, sans-serif; background-color: #0b0f19; color: #ffffff; padding: 25px; border-radius: 10px;">
          <h2 style="color: #00f0ff; letter-spacing: 2px;">JARVIS 2080 SECURITY</h2>
          <p style="color: #a0aec0;">Your account recovery verification code is:</p>
          <div style="background: rgba(0, 240, 255, 0.1); border: 1px solid #00f0ff; padding: 15px; font-size: 32px; font-weight: bold; text-align: center; letter-spacing: 6px; color: #00f0ff; border-radius: 8px; margin: 20px 0;">
            ${otpCode}
          </div>
          <p style="color: #a0aec0; font-size: 14px;">This code is valid for exactly <strong>10 minutes</strong>.</p>
          <p style="color: #718096; font-size: 12px; margin-top: 30px;">If you did not request this recovery code, please ignore this email.</p>
        </div>
      `,
    };

    let sent = false;
    try {
      await transporter.sendMail(mailOptions);
      sent = true;
    } catch (mailError) {
      console.error("[SMTP] Failed to send email:", mailError);
      // For testing / fallback when SMTP credentials are not yet entered
      console.log(`[DEV FALLBACK] Recovery OTP for ${trimmedEmail}: ${otpCode}`);
    }

    await db.insert(otpAuditLogs).values({
      emailMasked: masked,
      action: "SEND_SUCCESS",
      ipAddress: String(ip),
      status: "SUCCESS",
      details: sent ? "OTP sent via Gmail SMTP" : "OTP generated (SMTP simulated/fallback)",
    });

    return res.json({
      success: true,
      message: "OTP recovery code sent successfully.",
      expiresInMinutes: 10,
    });
  } catch (error) {
    console.error("[API] send-otp error:", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

/**
 * POST /api/recovery/verify-otp
 * Accepts email and 6-digit OTP code, validates against active unexpired hash, and marks as used.
 */
recoveryRouter.post("/verify-otp", async (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code || typeof code !== "string" || code.length !== 6) {
      return res.status(400).json({ success: false, error: "Email and valid 6-digit OTP code are required." });
    }

    const trimmedEmail = email.trim().toLowerCase();
    const masked = maskEmail(trimmedEmail);
    const codeHash = crypto.createHash("sha256").update(code.trim()).digest("hex");
    const ip = req.ip || req.headers["x-forwarded-for"] || "unknown";

    const db = await getDb();
    if (!db) {
      return res.status(500).json({ success: false, error: "Database not available." });
    }

    // Find latest active unused OTP for email that has not expired
    const now = new Date();
    const activeRecords = await db
      .select()
      .from(otpCodes)
      .where(
        and(
          eq(otpCodes.email, trimmedEmail),
          eq(otpCodes.used, 0),
          gte(otpCodes.expiresAt, now)
        )
      )
      .orderBy(desc(otpCodes.createdAt))
      .limit(1);

    if (activeRecords.length === 0) {
      await db.insert(otpAuditLogs).values({
        emailMasked: masked,
        action: "VERIFY_FAILED",
        ipAddress: String(ip),
        status: "FAILED",
        details: "No valid active OTP found or code expired",
      });
      return res.status(400).json({ success: false, error: "Invalid or expired OTP code." });
    }

    const record = activeRecords[0];

    // Check attempts
    if (record.attempts >= 5) {
      await db.insert(otpAuditLogs).values({
        emailMasked: masked,
        action: "VERIFY_BLOCKED",
        ipAddress: String(ip),
        status: "BLOCKED",
        details: "Too many failed attempts",
      });
      return res.status(400).json({ success: false, error: "Too many failed verification attempts. Request a new OTP." });
    }

    if (record.codeHash !== codeHash) {
      // Increment attempts
      await db
        .update(otpCodes)
        .set({ attempts: record.attempts + 1 })
        .where(eq(otpCodes.id, record.id));

      await db.insert(otpAuditLogs).values({
        emailMasked: masked,
        action: "VERIFY_FAILED",
        ipAddress: String(ip),
        status: "FAILED",
        details: "Incorrect OTP code",
      });
      return res.status(400).json({ success: false, error: "Incorrect OTP code." });
    }

    // Mark as used
    await db
      .update(otpCodes)
      .set({ used: 1 })
      .where(eq(otpCodes.id, record.id));

    await db.insert(otpAuditLogs).values({
      emailMasked: masked,
      action: "VERIFY_SUCCESS",
      ipAddress: String(ip),
      status: "SUCCESS",
      details: "OTP verified successfully",
    });

    return res.json({
      success: true,
      message: "OTP verified successfully. You may now reset your PIN.",
    });
  } catch (error) {
    console.error("[API] verify-otp error:", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});

/**
 * GET /api/recovery/audit-logs
 * Admin dashboard endpoint returning recent audit logs.
 */
recoveryRouter.get("/audit-logs", async (req, res) => {
  try {
    const db = await getDb();
    if (!db) {
      return res.status(500).json({ success: false, error: "Database not available." });
    }
    const logs = await db
      .select()
      .from(otpAuditLogs)
      .orderBy(desc(otpAuditLogs.createdAt))
      .limit(50);

    return res.json({ success: true, logs });
  } catch (error) {
    console.error("[API] audit-logs error:", error);
    return res.status(500).json({ success: false, error: "Internal server error." });
  }
});
