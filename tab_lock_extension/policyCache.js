(function attachJarvisPolicyCache(scope) {
  function persistentPolicy(policy) {
    const { unlockSalt, unlockVerifier, ...safePolicy } = policy || {};
    return safePolicy;
  }

  function sessionCredentials(policies) {
    return Object.fromEntries((policies || [])
      .filter((policy) => policy?.mode === "lock" && policy.unlockSalt && policy.unlockVerifier)
      .map((policy) => [policy.domain, { unlockSalt: policy.unlockSalt, unlockVerifier: policy.unlockVerifier }]));
  }

  const api = { persistentPolicy, sessionCredentials };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  scope.JarvisTabLockPolicyCache = api;
})(typeof self !== "undefined" ? self : globalThis);
