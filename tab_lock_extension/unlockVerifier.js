(function attachJarvisUnlockVerifier(scope) {
  function verifierInput(salt, domain, secret) {
    return `${salt}|${domain}|${secret}`;
  }

  function matchesVerifier(candidate, expected) {
    return typeof candidate === "string" && typeof expected === "string" && candidate.length === expected.length && candidate === expected;
  }

  const api = { verifierInput, matchesVerifier };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  scope.JarvisTabLockVerifier = api;
})(typeof self !== "undefined" ? self : globalThis);
