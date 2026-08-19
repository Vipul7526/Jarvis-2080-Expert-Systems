import crypto from "crypto";

const ENVELOPE_VERSION = "v1";
const KEY_PATTERN = /^[a-f0-9]{64}$/i;

export type TabLockCredentialMaterial = {
  unlockSalt: string;
  unlockVerifier: string;
};

function encryptionKey(): Buffer {
  const configured = process.env.TAB_LOCK_ENCRYPTION_KEY ?? "";
  if (!KEY_PATTERN.test(configured)) {
    throw new Error("TAB_LOCK_ENCRYPTION_KEY must be a 64-character hexadecimal AES-256 key.");
  }
  return Buffer.from(configured, "hex");
}

export function tabLockEncryptionReady(): boolean {
  return KEY_PATTERN.test(process.env.TAB_LOCK_ENCRYPTION_KEY ?? "");
}

export function encryptTabLockCredential(material: TabLockCredentialMaterial): string {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", encryptionKey(), iv);
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(material), "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [ENVELOPE_VERSION, iv.toString("base64url"), tag.toString("base64url"), ciphertext.toString("base64url")].join(".");
}

export function decryptTabLockCredential(envelope: string): TabLockCredentialMaterial {
  const [version, encodedIv, encodedTag, encodedCiphertext, extra] = envelope.split(".");
  if (version !== ENVELOPE_VERSION || !encodedIv || !encodedTag || !encodedCiphertext || extra) {
    throw new Error("Malformed Tab Lock encrypted credential envelope.");
  }
  const decipher = crypto.createDecipheriv("aes-256-gcm", encryptionKey(), Buffer.from(encodedIv, "base64url"));
  decipher.setAuthTag(Buffer.from(encodedTag, "base64url"));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(encodedCiphertext, "base64url")),
    decipher.final(),
  ]).toString("utf8");
  const decoded = JSON.parse(plaintext) as Partial<TabLockCredentialMaterial>;
  if (typeof decoded.unlockSalt !== "string" || typeof decoded.unlockVerifier !== "string") {
    throw new Error("Invalid Tab Lock credential envelope payload.");
  }
  return { unlockSalt: decoded.unlockSalt, unlockVerifier: decoded.unlockVerifier };
}
