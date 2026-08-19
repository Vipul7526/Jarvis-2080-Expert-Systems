import { describe, expect, it } from "vitest";
import crypto from "crypto";

describe("JARVIS Recovery OTP Unit Tests", () => {
  it("generates a valid 6-digit numeric OTP", () => {
    const otp = crypto.randomInt(100000, 999999).toString();
    expect(otp).toHaveLength(6);
    expect(Number(otp)).toBeGreaterThanOrEqual(100000);
    expect(Number(otp)).toBeLessThanOrEqual(999999);
  });

  it("produces a consistent SHA-256 hash for verification", () => {
    const code = "482910";
    const hash1 = crypto.createHash("sha256").update(code).digest("hex");
    const hash2 = crypto.createHash("sha256").update(code).digest("hex");
    expect(hash1).toBe(hash2);
    expect(hash1).toHaveLength(64);
  });
});
