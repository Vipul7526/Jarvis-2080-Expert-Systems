# Tab Lock Security Model

## Credential handling

Tab Lock never sends a plaintext website password, PIN, or passphrase to the backend. Android computes a verifier from `SHA-256(salt | normalized-domain | secret)` and sends only the random salt and resulting verifier over authenticated TLS requests.

The backend encrypts that salt/verifier pair with **AES-256-GCM** before writing it to `tab_lock_policies.unlockCredentialCiphertext`. The encryption key is the server-only `TAB_LOCK_ENCRYPTION_KEY` secret and is not included in source code, the Android APK, the Chrome extension, API responses, or database migrations. Legacy policies that predate this field are migrated during their next authenticated policy sync; their old plaintext columns are set to `NULL` after the encrypted envelope is written.

The Chrome extension must receive verifier material to check a local unlock attempt. It keeps that material only in `chrome.storage.session`, which is cleared when Chrome closes. It persists only non-secret policy metadata and its device bearer token in `chrome.storage.local`. A Chrome profile is therefore a trusted device boundary; removing or revoking a device prevents future server sync, but any already-installed local DNR block rule continues until the extension processes a later sync or is removed.

## Non-claims and operational guidance

Tab Lock is a browser policy feature, not a content proxy, malware scanner, parental-control bypass, or WebAuthn implementation. It protects direct Chrome navigation on the enrolled profile; it cannot control another browser, native app traffic, or a user who can modify/disable the extension. Choose a long, unique passphrase for credential locks, keep the Android controller locked, and revoke Chrome devices from Tab Lock whenever a computer or browser profile is no longer trusted.
