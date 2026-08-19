import crypto from "crypto";
import { describe, expect, it } from "vitest";
import matcher from "../../jarvis_assistant/tab_lock_extension/policyMatcher.js";
import cache from "../../jarvis_assistant/tab_lock_extension/policyCache.js";
import verifier from "../../jarvis_assistant/tab_lock_extension/unlockVerifier.js";
import { deviceCanSync } from "./tabLockRouter";

describe("Tab Lock effective browser behavior", () => {
  it("matches the protected domain, subdomains, and paths but not lookalike hostnames", () => {
    const policy = { domain: "example.com" };
    expect(matcher.policyMatchesUrl(policy, "https://example.com/private/path?x=1")).toBe(true);
    expect(matcher.policyMatchesUrl(policy, "https://docs.example.com/guide")).toBe(true);
    expect(matcher.policyMatchesUrl(policy, "http://api.docs.example.com/v1")).toBe(true);
    expect(matcher.policyMatchesUrl(policy, "https://example.com.evil.test/path")).toBe(false);
    expect(matcher.policyMatchesUrl(policy, "chrome://settings")).toBe(false);
  });

  it("accepts the correct unlock secret and rejects an incorrect unlock secret", () => {
    const salt = "test-salt-please-replace";
    const domain = "example.com";
    const correctSecret = "4815";
    const verifierHash = crypto.createHash("sha256").update(verifier.verifierInput(salt, domain, correctSecret)).digest("hex");
    const correctCandidate = crypto.createHash("sha256").update(verifier.verifierInput(salt, domain, correctSecret)).digest("hex");
    const incorrectCandidate = crypto.createHash("sha256").update(verifier.verifierInput(salt, domain, "4816")).digest("hex");
    expect(verifier.matchesVerifier(correctCandidate, verifierHash)).toBe(true);
    expect(verifier.matchesVerifier(incorrectCandidate, verifierHash)).toBe(false);
  });

  it("keeps unlock verifier material out of persistent extension policy storage", () => {
    const policy = { domain: "example.com", mode: "lock", unlockSalt: "salt", unlockVerifier: "b".repeat(64) };
    expect(cache.persistentPolicy(policy)).toEqual({ domain: "example.com", mode: "lock" });
    expect(cache.sessionCredentials([policy])).toEqual({
      "example.com": { unlockSalt: "salt", unlockVerifier: "b".repeat(64) },
    });
  });

  it("does not allow a revoked or expired extension to synchronize policies", () => {
    const future = new Date(Date.now() + 60_000);
    const past = new Date(Date.now() - 60_000);
    expect(deviceCanSync({ revoked: 0, expiresAt: future })).toBe(true);
    expect(deviceCanSync({ revoked: 1, expiresAt: future })).toBe(false);
    expect(deviceCanSync({ revoked: 0, expiresAt: past })).toBe(false);
  });
});
