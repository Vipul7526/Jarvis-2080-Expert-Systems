const API_DEFAULT = "https://jarvisrecov-3mlp5xq9.manus.space/api/tab-lock";
importScripts("policyMatcher.js", "unlockVerifier.js", "policyCache.js");

const RULE_BASE = 1000;
const pendingUrls = new Map(); // tabId -> { domain, url }
const unlockGrants = new Map();
const failedAttempts = new Map();

function policyKey(domain) {
  return `policy:${domain}`;
}

function escapeRegex(value) {
  return value.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
}

function urlRegex(domain) {
  return `^https?://([^./]+\\.)?${escapeRegex(domain)}(/|$)`;
}

async function getConfig() {
  return chrome.storage.local.get({
    apiBase: API_DEFAULT,
    deviceId: "",
    deviceName: "Chrome Browser",
    token: "",
    groupId: "",
    policies: [],
    syncError: ""
  });
}

async function getSessionCredentials() {
  const { tabLockCredentials = {} } = await chrome.storage.session.get({ tabLockCredentials: {} });
  return tabLockCredentials;
}

async function apiRequest(path, options = {}) {
  const config = await getConfig();
  if (!config.token && path !== "/register") throw new Error("Extension is not paired.");
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (config.token) headers.Authorization = `Bearer ${config.token}`;
  const response = await fetch(`${config.apiBase}${path}`, { ...options, headers });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || body.success === false) throw new Error(body.error || `Request failed (${response.status})`);
  return body;
}

async function installRules(policies) {
  const existing = await chrome.declarativeNetRequest.getDynamicRules();
  const removeRuleIds = existing.map((rule) => rule.id);
  const addRules = [];
  let ruleId = RULE_BASE;
  for (const policy of policies) {
    if (!policy || !policy.domain || !["block", "lock"].includes(policy.mode)) continue;
    if (unlockGrants.has(policy.domain)) continue;
    addRules.push({
      id: ruleId++,
      priority: 1,
      action: {
        type: "redirect",
        redirect: {
          extensionPath: "pages/blocked.html"
        }
      },
      condition: {
        regexFilter: urlRegex(policy.domain),
        resourceTypes: ["main_frame"]
      }
    });
  }
  await chrome.declarativeNetRequest.updateDynamicRules({ removeRuleIds, addRules });
}

async function syncPolicies() {
  const config = await getConfig();
  if (!config.deviceId || !config.token) return { success: false, error: "Pair the extension from the options page first." };
  try {
    const body = await apiRequest(`/sync?deviceId=${encodeURIComponent(config.deviceId)}`);
    const policies = body.policies || [];
    const credentials = JarvisTabLockPolicyCache.sessionCredentials(policies);
    const safePolicies = policies.map(JarvisTabLockPolicyCache.persistentPolicy);
    await chrome.storage.local.set({ groupId: body.groupId || config.groupId, policies: safePolicies, devices: body.devices || [], syncError: "" });
    await chrome.storage.session.set({ tabLockCredentials: credentials });
    await installRules(safePolicies);
    return { success: true, policies: safePolicies };
  } catch (error) {
    await chrome.storage.local.set({ syncError: String(error.message || error) });
    return { success: false, error: String(error.message || error) };
  }
}

async function registerExtension(deviceName) {
  const deviceId = `chrome-${crypto.randomUUID()}`;
  const body = await apiRequest("/register", {
    method: "POST",
    body: JSON.stringify({ deviceId, deviceType: "chrome", deviceName })
  });
  await chrome.storage.local.set({ deviceId, deviceName, token: body.accessToken, groupId: body.groupId, policies: [], devices: [] });
  return { success: true, deviceId, groupId: body.groupId, pairingCode: body.pairingCode, pairingExpiresAt: body.pairingExpiresAt };
}

async function sha256Hex(value) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function findPolicy(domain) {
  return chrome.storage.local.get({ policies: [] }).then(({ policies }) => policies.find((policy) => policy.domain === domain));
}

async function clearGrant(domain) {
  unlockGrants.delete(domain);
  await installRules((await getConfig()).policies || []);
}

async function attemptUnlock(domain, secret, tabId) {
  const policy = await findPolicy(domain);
  const credentials = await getSessionCredentials();
  const credential = credentials[domain];
  if (!policy || policy.mode !== "lock" || !credential?.unlockSalt || !credential?.unlockVerifier) return { success: false, error: "The lock credential is not available yet. Sync Tab Lock while online, then try again." };
  const previous = failedAttempts.get(domain) || { count: 0, lockedUntil: 0 };
  if (previous.lockedUntil > Date.now()) return { success: false, error: "Too many attempts. Try again later." };
  const verifier = await sha256Hex(JarvisTabLockVerifier.verifierInput(credential.unlockSalt, domain, secret));
  if (!JarvisTabLockVerifier.matchesVerifier(verifier, credential.unlockVerifier)) {
    const count = previous.count + 1;
    failedAttempts.set(domain, { count, lockedUntil: count >= 5 ? Date.now() + 60000 : 0 });
    return { success: false, error: count >= 5 ? "Too many attempts. Locked for 60 seconds." : "Incorrect password, PIN, or passkey." };
  }
  failedAttempts.delete(domain);
  unlockGrants.set(domain, { grantedAt: Date.now() });
  await installRules((await getConfig()).policies || []);
  return { success: true, url: pendingUrls.get(tabId)?.url || "" };
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create("jarvis-policy-sync", { periodInMinutes: 5 });
  syncPolicies();
});

chrome.runtime.onStartup.addListener(() => {
  chrome.alarms.create("jarvis-policy-sync", { periodInMinutes: 5 });
  syncPolicies();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "jarvis-policy-sync") syncPolicies();
});

chrome.webNavigation.onBeforeNavigate.addListener(async (details) => {
  if (details.frameId !== 0 || !/^https?:\/\//i.test(details.url)) return;
  const url = new URL(details.url);
  const config = await getConfig();
  const policy = (config.policies || []).find((item) => JarvisTabLockMatcher.policyMatchesUrl(item, url.href));
  if (policy) pendingUrls.set(details.tabId, { domain: policy.domain, url: details.url });
});

chrome.webNavigation.onCommitted.addListener(async (details) => {
  if (details.frameId !== 0 || !/^https?:\/\//i.test(details.url)) return;
  const url = new URL(details.url);
  const config = await getConfig();
  const policy = (config.policies || []).find((item) => JarvisTabLockMatcher.policyMatchesUrl(item, url.href));
  if (!policy || !policy.relockOnRefresh || !unlockGrants.has(policy.domain)) return;
  const grant = unlockGrants.get(policy.domain);
  if (grant && Date.now() - grant.grantedAt > 2500 && details.transitionType === "reload") await clearGrant(policy.domain);
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    try {
      if (message.type === "register") return sendResponse(await registerExtension(message.deviceName || "Chrome Browser"));
      if (message.type === "sync") return sendResponse(await syncPolicies());
      if (message.type === "getState") return sendResponse(await getConfig());
      if (message.type === "getPolicy") return sendResponse({ success: true, policy: await findPolicy(message.domain) });
      if (message.type === "getBlockedState") {
        const pending = sender.tab?.id == null ? null : pendingUrls.get(sender.tab.id);
        const policy = pending ? await findPolicy(pending.domain) : null;
        return sendResponse({ success: true, domain: pending?.domain || "", url: pending?.url || "", policy });
      }
      if (message.type === "unlock") return sendResponse(await attemptUnlock(message.domain, message.secret || "", sender.tab?.id));
      if (message.type === "openOptions") {
        await chrome.runtime.openOptionsPage();
        return sendResponse({ success: true });
      }
      sendResponse({ success: false, error: "Unsupported message." });
    } catch (error) {
      sendResponse({ success: false, error: String(error.message || error) });
    }
  })();
  return true;
});
