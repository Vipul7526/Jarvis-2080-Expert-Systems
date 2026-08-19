let domain = "";
let originalUrl = "";
let failurePage = "blocked";

const title = document.getElementById("title");
const domainNode = document.getElementById("domain");
const message = document.getElementById("message");
const form = document.getElementById("unlockForm");
const secret = document.getElementById("secret");
const error = document.getElementById("error");

function renderPage() {
  domainNode.textContent = domain || "this website";
  if (failurePage === "forbidden") {
    title.textContent = "Forbidden";
    message.textContent = "JARVIS has marked this domain as unavailable on this browser.";
  } else if (failurePage === "not_found") {
    title.textContent = "404 — Route unavailable";
    message.textContent = "This route is intentionally hidden by a JARVIS policy.";
  } else if (failurePage === "aw_snap") {
    title.textContent = "Aw, snap!";
    message.textContent = "JARVIS prevented this page from loading on the selected device.";
  }
}

chrome.runtime.sendMessage({ type: "getBlockedState" }, (result) => {
  if (!result?.success || !result.domain) {
    title.textContent = "Access controlled";
    message.textContent = "This page was blocked by JARVIS, but its policy context is unavailable. Open extension settings to review pairing.";
    return;
  }
  domain = result.domain;
  originalUrl = result.url || "";
  failurePage = result.policy?.failurePage || "blocked";
  renderPage();
  if (result.policy?.mode === "lock") {
    form.classList.remove("hidden");
    title.textContent = "Credential required";
    message.textContent = "This site is locked. Enter the credential configured in JARVIS Tab Lock.";
    secret.focus();
  }
});

form.addEventListener("submit", (event) => {
  event.preventDefault();
  error.textContent = "Checking…";
  chrome.runtime.sendMessage({ type: "unlock", domain, secret: secret.value }, (result) => {
    if (!result?.success) {
      error.textContent = result?.error || "Unlock failed.";
      secret.select();
      return;
    }
    error.textContent = "Unlocked. Returning to the requested page…";
    if (result.url || originalUrl) location.replace(result.url || originalUrl);
    else history.back();
  });
});

document.getElementById("options").addEventListener("click", () => {
  chrome.runtime.sendMessage({ type: "openOptions" });
});
