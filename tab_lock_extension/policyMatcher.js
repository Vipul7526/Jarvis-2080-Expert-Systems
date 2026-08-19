(function attachJarvisPolicyMatcher(scope) {
  function policyMatchesUrl(policy, candidateUrl) {
    if (!policy || typeof policy.domain !== "string" || typeof candidateUrl !== "string") return false;
    try {
      const url = new URL(candidateUrl);
      if (url.protocol !== "https:" && url.protocol !== "http:") return false;
      const domain = policy.domain.trim().toLowerCase().replace(/^www\./, "").replace(/\.$/, "");
      const hostname = url.hostname.toLowerCase().replace(/\.$/, "");
      return hostname === domain || hostname.endsWith(`.${domain}`);
    } catch (_) {
      return false;
    }
  }

  const api = { policyMatchesUrl };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  scope.JarvisTabLockMatcher = api;
})(typeof self !== "undefined" ? self : globalThis);
