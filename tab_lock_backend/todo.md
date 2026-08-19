# Project TODO

- [x] Initialize backend project structure with TypeScript, Express, and Drizzle
- [x] Implement database schema for OTP codes, audit logs, and rate limiting
- [x] Implement Gmail SMTP service using Nodemailer and server-side app password
- [x] Implement POST /api/recovery/send-otp with 10-minute validity and hourly rate limit (max 3/hr)
- [x] Implement POST /api/recovery/verify-otp with strict validation
- [x] Configure strict CORS for JARVIS app origin and security headers
- [x] Build owner-only admin dashboard for viewing recent OTP audit logs
- [x] Write Vitest test suite for OTP generation, rate limiting, and verification
- [x] Configure environment secrets (Gmail user & app password) via webdev_request_secrets
- [x] Expose backend port and verify live endpoints
- [x] Update Flutter app EmailService with live backend URL and rebuild APK
- [x] Deliver APK, backend access, and Google OAuth setup guide

## JARVIS mesh relay expansion — 2026-08-16

- [x] Add a database-backed authenticated relay queue for non-nearby paired devices.
- [x] Add request polling and message acknowledgement endpoints with expiry and size limits.
- [x] Add tests for relay authentication, expiry, rejection, and acknowledgement.
- [x] Apply the schema migration and verify the production server build.

## JARVIS Android release verification — 2026-08-16

- [x] Complete 8 MB authenticated chunked file download and upload flow in the visual mesh file manager.
- [x] Preserve remote GPS, battery percentage, and charging-state handling in the GPS Viewer event path.
- [x] Add regression coverage for mesh telemetry and chunk-response metadata.
- [x] Run Flutter mesh and command-router tests plus backend Vitest relay tests.
- [x] Build and verify the signed release APK for package com.ultimate.jarvis.pro with Firebase configuration.

## Follow-up quality notes

- [x] Clean pre-existing Flutter analyzer warnings in unrelated legacy screens and services.
- [x] Upgrade Android compileSdk to 35 to remove the flutter_plugin_android_lifecycle build warning.
- [x] Confirmed ADB is present but no Android devices are attached in the sandbox; documented the remaining physical two-device NSD, relay, and chunk-transfer checklist for user-side verification.


## JARVIS Android bug-fix pass — 2026-08-16

- [x] Fix the LAN mesh connection response type-cast failure shown on the controller device.
- [x] Ensure remote GPS Viewer requests and device-status responses update latitude, longitude, battery, and charging state on the controller.
- [x] Replace package-name-only app command output with an explicit `y- open` / `y- install` confirmation flow and safe package launching.
- [x] Replace continuous speech recognition microphone capture with a lower-power Android wake-word listening architecture.
- [x] Add regression tests for the corrected mesh response envelope and command confirmation states.
- [x] Rebuild and verify the signed release APK with the bug fixes.
- [x] Update the release setup guide with wake-word power behavior and the new package confirmation commands.

## JARVIS live distance and wake-word visual pass — 2026-08-16

- [x] Calculate the real-time distance between the controller and connected target using fresh coordinates.
- [x] Display distance, freshness, and unavailable states in the GPS Viewer.
- [x] Add a cyberpunk visual indicator and animation when the wake-word/assistant trigger is received.
- [x] Add regression coverage for distance calculation and wake-trigger state transitions.
- [x] Rebuild and verify the signed APK with the new features.
- [x] Update the release guide with distance and wake-trigger usage notes.

## Verification gap follow-up — 2026-08-16

- [x] Propagate native GPS fix timestamps for local and remote devices and reject stale fixes before distance calculation.
- [x] Distinguish fresh, stale, and unavailable GPS states in the GPS Viewer instead of using UI update time as freshness.
- [x] Trigger the assistant pulse only from an actual assistant/wake trigger signal, not plain assistant-screen initialization.
- [x] Add widget or unit coverage for wake-trigger state transitions.

## Refreshed Firebase Android configuration — 2026-08-16

- [ ] Validate the uploaded `google-services.json` contains the Android OAuth client for the package and release certificate.
- [ ] Replace the project Firebase configuration with the refreshed uploaded file.
- [ ] Rebuild and verify the signed APK using the refreshed Firebase configuration.
- [ ] Run the final local Google Sign-In configuration tests and update the release guide checksum.

## New release keystore migration — 2026-08-16

- [ ] Generate a new RSA release keystore and retain its alias/password configuration outside source code where possible.
- [ ] Compute and record the new release SHA-1 and SHA-256 certificate fingerprints.
- [ ] Configure the Android release build to use the new keystore and ensure the keystore is never committed to source control.
- [ ] Update Firebase Android app fingerprints and Google OAuth setup instructions for the new signing certificate.
- [ ] Rebuild and verify the newly signed APK with the refreshed Firebase configuration.
- [ ] Deliver the APK, keystore backup, fingerprints, and durable backup instructions.

## JARVIS Tab Lock extension — 2026-08-19

- [x] Add authenticated Tab Lock device registration and policy storage.
- [x] Add encrypted-at-rest site unlock credential handling without plaintext passwords or passkeys.
- [x] Add extension policy sync procedures with device revocation and expiry handling.
- [x] Add Vitest coverage for domain matching, policy authorization, unlock challenge flow, and device revocation.
- [x] Document Chrome MV3 load-unpacked setup and secure Android-to-extension pairing.
- [x] Add true at-rest protection for Tab Lock credential material, or document and enforce the exact hashed-verifier security model.
- [x] Add Vitest cases for successful/failed unlock challenge flow, device revocation preventing sync, and effective domain/subdomain/path policy matching.
- [x] Document the end-to-end server-encrypted and extension session-only Tab Lock verifier storage model.
