const $ = (id) => document.getElementById(id);

function setStatus(message, error = false) {
  const node = $("status");
  node.textContent = message;
  node.style.color = error ? "#ff9bca" : "#bafcff";
}

function render(state) {
  $("apiBase").value = state.apiBase || "https://jarvisrecov-3mlp5xq9.manus.space/api/tab-lock";
  $("deviceName").value = state.deviceName || "Chrome Browser";
  const paired = Boolean(state.token && state.groupId);
  $("pairedState").textContent = paired ? "Paired" : "Not paired";
  const details = $("deviceDetails");
  details.innerHTML = "";
  [["Name", state.deviceName || "—"], ["Device ID", state.deviceId || "—"], ["Group", state.groupId || "—"]].forEach(([key, value]) => {
    const dt = document.createElement("dt"); dt.textContent = key;
    const dd = document.createElement("dd"); dd.textContent = value;
    details.append(dt, dd);
  });
  const policies = state.policies || [];
  $("ruleCount").textContent = String(policies.length);
  const rules = $("rules");
  rules.innerHTML = "";
  if (!policies.length) {
    rules.innerHTML = '<p class="muted">No policies synced yet. Create them from the Android Tab Lock tab.</p>';
  } else {
    policies.forEach((policy) => {
      const row = document.createElement("div"); row.className = "rule";
      const domain = document.createElement("span"); domain.className = "domain"; domain.textContent = policy.domain;
      const mode = document.createElement("span"); mode.className = "mode"; mode.textContent = policy.mode === "lock" ? "credential lock" : "blocked";
      row.append(domain, mode); rules.append(row);
    });
  }
  if (state.syncError) setStatus(state.syncError, true);
}

async function load() {
  const state = await chrome.runtime.sendMessage({ type: "getState" });
  render(state || {});
}

$("register").addEventListener("click", async () => {
  const deviceName = $("deviceName").value.trim() || "Chrome Browser";
  await chrome.storage.local.set({ apiBase: $("apiBase").value.trim() });
  $("register").disabled = true;
  setStatus("Generating a one-time pairing code…");
  const result = await chrome.runtime.sendMessage({ type: "register", deviceName });
  $("register").disabled = false;
  if (!result?.success) return setStatus(result?.error || "Registration failed.", true);
  $("pairing").classList.remove("hidden");
  $("pairingCode").textContent = result.pairingCode;
  $("expires").textContent = `Expires: ${new Date(result.pairingExpiresAt).toLocaleString()}`;
  setStatus("Code generated. Enter it in JARVIS → Tab Lock on Android, then sync.");
  await load();
});

$("sync").addEventListener("click", async () => {
  await chrome.storage.local.set({ apiBase: $("apiBase").value.trim(), deviceName: $("deviceName").value.trim() });
  setStatus("Syncing policies…");
  const result = await chrome.runtime.sendMessage({ type: "sync" });
  if (!result?.success) return setStatus(result?.error || "Sync failed.", true);
  setStatus(`Synced ${result.policies.length} policy${result.policies.length === 1 ? "" : "ies"}.`);
  await load();
});

load();
