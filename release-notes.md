JARVIS 2080 Pro v1.1.0 Release

- Signed release APK (`com.ultimate.jarvis.pro`)
- Refreshed Firebase configuration with correct SHA-1 and SHA-256 fingerprints
- Cyberpunk assistant UI with native accessibility and mesh networking


JARVIS 2080 Pro v1.2.3 Release

- Clean Flutter release compilation completed; the Flutter kernel snapshot was not skipped.
- Orbitron.ttf is embedded in the APK and registered as the global Orbitron font family.
- Added the animated holographic spherical onboarding core with the visible “CORE ONLINE” indicator.
- Registered the native MeshBridge channel and preserved the real mesh, terminal, app-launch, GPS, and authentication integrations.
- APK package: `com.ultimate.jarvis.pro`; version name: `1.2.3`.
- Release build verification: embedded Orbitron asset and updated UI strings confirmed in the APK.

Copyright: © 2026 Prince Singh. All Rights Reserved.


JARVIS 2080 Pro v1.2.4 Release

- Mobile-first holographic cockpit inspired by the supplied sphere and listening references, with responsive particle rendering for idle, listening, thinking, and talking states.
- Orbitron is registered as the global font family and embedded in the signed APK.
- Added command-center chips, compact navigation, real microphone transcription flow, and a 100+ safe command catalog built around native actions and explicit unsupported-command responses.
- Hardened real LAN mesh discovery and pairing: six-digit code validation, pending request approval, peer persistence, and native socket lifecycle fixes.
- Removed fake GPS coordinates and fail-open biometric behavior; unavailable permissions and native failures are shown honestly.
- Added an isolated neon-green **PRANK MODE — SIMULATION ONLY** dashboard. It is local entertainment UI only and has no scanning, password cracking, surveillance, crypto-mining, target connection, or infrastructure-control capability.
- APK package: `com.ultimate.jarvis.pro`; version name: `1.2.4`; release artifact is arm64-v8a and signed with the existing release identity.
- Final verification: Flutter release compilation, Kotlin compilation, APK v2 signature verification, embedded Orbitron.ttf, FontManifest registration, package metadata, and widget tests completed.

Copyright: © 2026 Prince Singh. All Rights Reserved.


JARVIS 2080 Pro v1.2.5 Release

- Removed the prior prank-only Hacking Dashboard; v1.2.5 contains no hacking dashboard or simulation navigation.
- Refined the mobile-first holographic core, state indicators, and Tab Lock management flow, with Orbitron embedded in the signed APK.
- Hardened natural-language app launching by resolving installed Android packages instead of relying on fixed aliases.
- Added the **JARVIS Tab Lock** Chrome Manifest V3 extension. It enforces complete domain, subdomain, and path policies, offers block/credential-lock modes, supports re-lock on refresh, and pairs to the Android controller using an eight-digit one-time code.
- The recovery server now encrypts Tab Lock salt/verifier bundles at rest with server-only AES-256-GCM. Chrome keeps verifier material only in session storage; it persists policy metadata and the browser device token, not the unlock verifier.
- Security regressions cover AES-GCM envelope integrity, server key readiness, successful/failed local verifier checks, domain/subdomain/path matching, extension cache sanitization, and revocation/expiry sync refusal.
- APK package: `com.ultimate.jarvis.pro`; version name: `1.2.5`; arm64-v8a; v2-signed. SHA-256: `f4d61861bb894eb1f87860b18442d13562ca87245fd8c820e00182e40d1feafa`.
- The release includes `JARVIS-Tab-Lock-Chrome-Extension-v1.2.5.zip`. Extract it and load the `tab_lock_extension` folder through `chrome://extensions` → **Developer mode** → **Load unpacked**.

Copyright: © 2026 Prince Singh. All Rights Reserved.
