# JARVIS Tab Lock Chrome Extension

This is a **Chrome Manifest V3 load-unpacked extension**. It is the browser enforcement component for the Android JARVIS **Tab Lock** tab.

## Install in Chrome

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Choose **Load unpacked**.
4. Select this `tab_lock_extension` directory.
5. Open the extension options page and choose **Generate pairing code**.
6. In the Android app, open **Tab Lock**, register the controller, enter the eight-digit code shown by the extension, and choose **Pair extension**.
7. Create domain policies in the Android Tab Lock tab. The extension syncs them immediately when requested and every five minutes through a Chrome alarm.

## Policy behavior

A domain policy matches the exact domain and every subdomain and path, for example `example.com`, `www.example.com`, and `example.com/account/settings`. **Fully block** redirects to a clearly labelled JARVIS page. **Credential lock** redirects to the same page and permits a session unlock after the browser extension verifies the client-generated hash. A refresh can re-lock the domain when that option is enabled.

The selected 404, Forbidden, Aw Snap, or JARVIS blocked appearance is a visual response page only. It does not modify the website, intercept non-browser traffic, or bypass authentication.

## Security boundary

The Android app derives a SHA-256 verifier from `salt | domain | secret`. The plaintext password, PIN, or passphrase is never sent to the backend or written to extension storage. The server stores the salt/verifier bundle only as an **AES-256-GCM encrypted envelope** using a server-only key. Existing legacy plaintext verifier columns are cleared automatically the next time that policy syncs.

The extension receives the salt/verifier only after an authenticated sync and keeps it in `chrome.storage.session`, not `chrome.storage.local`; closing Chrome clears that verifier cache. A tested cache sanitizer removes `unlockSalt` and `unlockVerifier` before policy metadata is written to persistent extension storage. The domain/mode/re-lock policy remains cached locally so an existing block can keep working while offline, but a credential lock needs a fresh online sync after Chrome is restarted before it can be unlocked. This is a deliberate confidentiality trade-off. Device bearer tokens remain in extension local storage so the extension can authenticate a future sync; treat browser profile access as trusted and revoke the device from Android if that profile is compromised.

Pairing codes are one-time and expire. Android stores its controller token in Android Keystore-backed Flutter Secure Storage. Revocation invalidates future sync requests immediately; locally installed dynamic block rules continue until the extension obtains the revocation response or is removed. This release does not claim WebAuthn hardware passkey support; use a strong unique passphrase for a credential lock.

## Availability

The policy API is deployed on the existing JARVIS recovery server and is available for requests through managed hosting. The extension is enforcement-capable while it has a valid cached policy, so a temporary server outage does not silently remove an existing local block. The server is not a long-running traffic proxy and does not need to inspect browser page contents.
