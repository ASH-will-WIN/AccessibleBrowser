const { app, BrowserWindow, WebContentsView, ipcMain } = require("electron");
const path = require("node:path");
const crypto = require("node:crypto");
const { pathToFileURL } = require("node:url");

const CHANNEL = "accessible-browser:";
const DEFAULT_URL = "https://example.com";
const TOOLBAR_HEIGHT = 150;
const MAX_TEXT = 12_000;
const MAX_ELEMENTS = 160;
const PAGE_WORLD_ID = 1001;
const ACTION_KINDS = new Set([
  "set_text_scale",
  "set_spacing",
  "set_contrast",
  "set_color_filter",
  "reduce_motion",
  "enlarge_targets",
  "hide_regions",
  "reading_mode",
  "focus_elements",
]);
const BROWSER_COMMAND_KINDS = new Set([
  "new_tab",
  "close_tab",
  "switch_tab",
  "back",
  "forward",
  "reload",
  "navigate",
  "scroll",
  "zoom",
  "search",
  "read_page",
  "stop_reading",
]);
const tabs = new Map();
let window;
let experienceWindow;
let activeTabId;
let tabSequence = 0;
const undoHistory = new Map();

const jacUiUrl = process.env.ACCESSIBLE_BROWSER_JAC_URL || "http://127.0.0.1:8000";
const jacApiUrl = process.env.ACCESSIBLE_BROWSER_JAC_API_URL || "http://127.0.0.1:8002";
const jacOperations = new Set([
  "get_active_profile",
  "update_active_profile",
  "get_applicable_preferences",
  "create_adaptation_request",
  "create_adaptation_plan",
  "explain_adaptation_plan",
  "record_apply_result",
  "propose_persistence",
  "save_approved_preference",
  "forward_browser_command",
]);

function makeId(prefix) {
  return `${prefix}_${crypto.randomUUID()}`;
}

function validObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function requireKeys(value, required, optional = []) {
  if (!validObject(value)) throw new Error("Expected a JSON object");
  const allowed = new Set([...required, ...optional]);
  if (Object.keys(value).some((key) => !allowed.has(key)) || required.some((key) => !(key in value))) {
    throw new Error("Message contains missing or unknown fields");
  }
}

function executePageScript(tab, code) {
  return tab.view.webContents.executeJavaScriptInIsolatedWorld(PAGE_WORLD_ID, [{ code }]);
}

function structuredError(error, requestId = makeId("request")) {
  const allowed = new Set(["INVALID_MESSAGE", "UNSUPPORTED_VERSION", "STALE_PAGE_REVISION", "TARGET_NOT_FOUND", "INVALID_PLAN", "UNSUPPORTED_ACTION", "INVALID_PARAMETERS", "APPLY_FAILED", "UNDO_FAILED", "SNAPSHOT_FAILED", "LLM_UNAVAILABLE", "TIMEOUT", "PERMISSION_DENIED", "USER_CANCELLED", "JAC_UNAVAILABLE"]);
  const code = allowed.has(error.code) ? error.code : "INVALID_MESSAGE";
  const detail = { schemaVersion: 1, requestId, code, message: error.message || "Request failed", retryable: error.retryable === true || code === "TIMEOUT" };
  return { status: "rejected", requestId, error: detail };
}

function bridgeError(code, message, retryable = false) {
  const error = new Error(message);
  error.code = code;
  error.retryable = retryable;
  return error;
}

async function callJac(operation, payload = {}) {
  if (!jacOperations.has(operation)) throw bridgeError("INVALID_MESSAGE", "Jac operation is not allowlisted.");
  let response;
  try {
    response = await fetch(`${jacApiUrl.replace(/\/$/, "")}/function/${operation}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  } catch (error) {
    throw bridgeError("JAC_UNAVAILABLE", `Jac service unavailable: ${error.message}`, true);
  }
  let envelope;
  try {
    envelope = await response.json();
  } catch {
    throw bridgeError("JAC_UNAVAILABLE", "Jac returned a non-JSON response.", true);
  }
  if (!response.ok || envelope.ok === false) {
    const detail = envelope.error?.message || `Jac request failed with HTTP ${response.status}.`;
    throw bridgeError(envelope.error?.code || "JAC_UNAVAILABLE", detail, response.status >= 500);
  }
  return envelope.data?.result ?? envelope.data ?? envelope;
}

function getActiveTab() {
  return tabs.get(activeTabId);
}

function notifyPageChanged(tab, reason) {
  if (tab.id === activeTabId) {
    const message = {
      schemaVersion: 1,
      tabId: tab.id,
      pageRevision: tab.pageRevision,
      url: redactUrl(tab.view.webContents.getURL()),
      title: tab.view.webContents.getTitle(),
      reason,
    };
    for (const uiWindow of [window, experienceWindow]) {
      if (uiWindow && !uiWindow.isDestroyed()) uiWindow.webContents.send(`${CHANNEL}page-changed`, message);
    }
  }
}

function bumpRevision(tab, reason) {
  tab.pageRevision += 1;
  tab.elementIds.clear();
  tab.lastMutationVersion = undefined;
  if (tab.lastUndoToken) undoHistory.delete(tab.lastUndoToken);
  tab.lastUndoToken = undefined;
  notifyPageChanged(tab, reason);
}

function isTrustedUi(sender) {
  const shellUrl = pathToFileURL(path.join(__dirname, "placeholder.html")).href;
  if (window && sender.id === window.webContents.id && sender.getURL() === shellUrl) return true;
  if (experienceWindow && sender.id === experienceWindow.webContents.id) {
    try { return new URL(sender.getURL()).origin === new URL(jacUiUrl).origin; } catch { return false; }
  }
  return false;
}

function register(channel, handler) {
  ipcMain.handle(`${CHANNEL}${channel}`, async (event, payload) => {
    try {
      if (!isTrustedUi(event.sender)) throw Object.assign(new Error("Permission denied"), { code: "PERMISSION_DENIED" });
      return await handler(payload);
    } catch (error) {
      return structuredError(error, payload?.requestId);
    }
  });
}

function safeUrl(raw) {
  if (typeof raw !== "string" || raw.length > 2048) throw new Error("Enter a URL under 2048 characters");
  let candidate = raw.trim();
  if (!candidate) throw new Error("Enter a URL");
  if (!/^[a-zA-Z][a-zA-Z\d+.-]*:/.test(candidate)) {
    candidate = candidate.includes(" ") ? `https://www.google.com/search?q=${encodeURIComponent(candidate)}` : `https://${candidate}`;
  }
  const parsed = new URL(candidate);
  if (!new Set(["http:", "https:"]).has(parsed.protocol)) throw new Error("Only HTTP and HTTPS pages can be opened");
  if (parsed.username || parsed.password) throw new Error("URLs with embedded credentials are not supported");
  return parsed.toString();
}

function commandError(code, message, retryable = false) {
  return Object.assign(new Error(message), { code, retryable });
}

function validateBrowserCommand(command) {
  requireKeys(command, ["schemaVersion", "requestId", "tabId", "kind", "arguments", "requiresConfirmation"]);
  if (command.schemaVersion !== 1) throw commandError("UNSUPPORTED_VERSION", "Unsupported browser command version.");
  if (typeof command.requestId !== "string" || command.requestId.length < 1 || command.requestId.length > 120 || typeof command.tabId !== "string" || typeof command.kind !== "string" || !validObject(command.arguments) || typeof command.requiresConfirmation !== "boolean") {
    throw commandError("INVALID_MESSAGE", "Invalid browser command envelope.");
  }
  if (!BROWSER_COMMAND_KINDS.has(command.kind)) throw commandError("UNSUPPORTED_ACTION", "Unsupported browser command.");

  const args = command.arguments;
  switch (command.kind) {
    case "new_tab":
      requireKeys(args, [], ["url"]);
      if (args.url !== undefined) safeUrl(args.url);
      break;
    case "close_tab":
    case "back":
    case "forward":
    case "reload":
    case "read_page":
    case "stop_reading":
      requireKeys(args, []);
      break;
    case "switch_tab":
      requireKeys(args, ["tabId"]);
      if (typeof args.tabId !== "string" || !args.tabId) throw commandError("INVALID_PARAMETERS", "A tabId is required to switch tabs.");
      break;
    case "navigate":
      requireKeys(args, ["url"]);
      safeUrl(args.url);
      break;
    case "scroll":
      requireKeys(args, ["deltaY"], ["deltaX"]);
      if (!Number.isFinite(args.deltaY) || Math.abs(args.deltaY) > 2000 || (args.deltaX !== undefined && (!Number.isFinite(args.deltaX) || Math.abs(args.deltaX) > 1000))) {
        throw commandError("INVALID_PARAMETERS", "Scroll distance is out of bounds.");
      }
      break;
    case "zoom":
      requireKeys(args, ["factor"]);
      if (!Number.isFinite(args.factor) || args.factor < 0.5 || args.factor > 2.5) throw commandError("INVALID_PARAMETERS", "Zoom factor must be between 0.5 and 2.5.");
      break;
    case "search":
      requireKeys(args, ["searchType"], ["query", "elementId"]);
      if (args.searchType === "focus_field") {
        requireKeys(args, ["searchType", "elementId"]);
        if (typeof args.elementId !== "string" || !args.elementId) throw commandError("INVALID_PARAMETERS", "A search field elementId is required.");
      } else {
        requireKeys(args, ["searchType", "query"]);
        if (!["web", "page"].includes(args.searchType) || typeof args.query !== "string" || args.query.length > 300 || !args.query.trim()) throw commandError("INVALID_PARAMETERS", "Search requires web or page and 1 to 300 characters of text.");
      }
      break;
  }
  if (command.kind === "close_tab" && !command.requiresConfirmation) return { cancelled: true };
  return { cancelled: false };
}

function redactUrl(raw) {
  try {
    const parsed = new URL(raw);
    const sensitive = /(token|secret|password|passwd|authorization|auth|session|csrf|api[_-]?key|access[_-]?key|refresh|jwt|signature|^code$)/i;
    for (const key of [...parsed.searchParams.keys()]) if (sensitive.test(key)) parsed.searchParams.set(key, "[redacted]");
    if (parsed.hash.includes("=")) {
      const fragment = new URLSearchParams(parsed.hash.slice(1));
      for (const key of [...fragment.keys()]) if (sensitive.test(key)) fragment.set(key, "[redacted]");
      parsed.hash = fragment.toString();
    }
    return parsed.toString();
  } catch {
    return "";
  }
}

function layoutViews() {
  if (!window || window.isDestroyed()) return;
  const [width, height] = window.getContentSize();
  for (const tab of tabs.values()) {
    tab.view.setBounds(tab.id === activeTabId
      ? { x: 0, y: TOOLBAR_HEIGHT, width, height: Math.max(0, height - TOOLBAR_HEIGHT) }
      : { x: 0, y: 0, width: 0, height: 0 });
  }
}

function createTab(url = DEFAULT_URL) {
  const id = `tab_${++tabSequence}`;
  const view = new WebContentsView({
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      webviewTag: false,
    },
  });
  const tab = { id, view, pageRevision: 0, elementIds: new Map(), lastMutationVersion: undefined, lastUndoToken: undefined };
  tabs.set(id, tab);
  window.contentView.addChildView(view);
  view.webContents.setWindowOpenHandler(({ url: target }) => {
    try { void navigate(tab, target).catch(() => {}); } catch { /* unsafe popups are discarded */ }
    return { action: "deny" };
  });
  view.webContents.on("will-attach-webview", (event) => event.preventDefault());
  view.webContents.on("will-navigate", (event, target) => {
    try { safeUrl(target); } catch { event.preventDefault(); }
  });
  view.webContents.on("will-redirect", (event, target) => {
    try { safeUrl(target); } catch { event.preventDefault(); }
  });
  view.webContents.on("did-start-navigation", (_event, _target, _inPlace, isMainFrame) => {
    if (isMainFrame) bumpRevision(tab, "navigation");
  });
  view.webContents.on("did-finish-load", () => notifyPageChanged(tab, "loaded"));
  view.webContents.on("did-fail-load", (_event, code, description, target, isMainFrame) => {
    if (isMainFrame && code !== -3 && window && !window.isDestroyed() && id === activeTabId) {
      window.webContents.send(`${CHANNEL}page-changed`, {
        schemaVersion: 1, tabId: id, pageRevision: tab.pageRevision, url: redactUrl(target), title: tab.view.webContents.getTitle(),
        reason: `load-error: ${description} (${code})`,
      });
    }
  });
  view.webContents.on("render-process-gone", (_event, details) => notifyPageChanged(tab, `renderer-error: ${details.reason}`));
  activeTabId = id;
  layoutViews();
  void navigate(tab, url).catch(() => {});
  return tab;
}

async function navigate(tab, rawUrl) {
  const url = safeUrl(rawUrl);
  await tab.view.webContents.loadURL(url);
  return { status: "completed", tabId: tab.id, url: redactUrl(tab.view.webContents.getURL()) };
}

async function pageState(tab) {
  const state = await executePageScript(tab, `(() => {
    if (!document.documentElement) throw new Error("The page is not ready for inspection.");
    const key = "__accessibleBrowserMutationVersion";
    const observerKey = key + "Observer";
    if (!Number.isInteger(window[key])) {
      window[key] = 0;
      const observer = new MutationObserver((records) => {
        if (records.length) window[key] += 1;
      });
      observer.observe(document.documentElement, { subtree: true, childList: true, attributes: true, characterData: true });
      window[observerKey] = observer;
    }
    const pending = window[observerKey]?.takeRecords() || [];
    if (pending.length) window[key] += 1;
    return { mutationVersion: window[key], url: location.href };
  })()`);
  if (!state || !Number.isInteger(state.mutationVersion)) throw Object.assign(new Error("The page state could not be read."), { code: "SNAPSHOT_FAILED", retryable: true });
  if (tab.lastMutationVersion !== undefined && state.mutationVersion !== tab.lastMutationVersion) bumpRevision(tab, "page-changed");
  tab.lastMutationVersion = state.mutationVersion;
  return state;
}

async function getPageSnapshot() {
  const tab = getActiveTab();
  if (!tab) throw new Error("No active page");
  try {
    await pageState(tab);
  } catch (error) {
    if (!error.code) error.code = "SNAPSHOT_FAILED";
    throw error;
  }
  const snapshotId = makeId("snapshot");
  let raw;
  try {
    raw = await executePageScript(tab, `(() => {
    if (!document.body) throw new Error("The page has no document body yet.");
    const max = ${MAX_ELEMENTS};
    const maxScan = 2500;
    const visible = (el) => {
      const rect = el.getBoundingClientRect();
      const style = getComputedStyle(el);
      return rect.width > 0 && rect.height > 0 && style.display !== "none" && style.visibility !== "hidden" && Number(style.opacity) !== 0;
    };
    const clean = (s, n = 240) => String(s || "").slice(0, n * 3).replace(/\\s+/g, " ").trim().slice(0, n);
    const selector = "h1,h2,h3,h4,h5,h6,button,a[href],input,textarea,select,[role=button],[role=link],[role=checkbox],[role=radio],[role=switch],main,article,section";
    const candidates = [];
    const elementWalker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT);
    let scannedElements = 0;
    let current;
    while ((current = elementWalker.nextNode()) && scannedElements < maxScan && candidates.length < max) {
      scannedElements += 1;
      if (current.matches(selector) && visible(current)) candidates.push(current);
    }
    const observer = window.__accessibleBrowserMutationVersionObserver;
    const pending = observer?.takeRecords() || [];
    if (pending.length) window.__accessibleBrowserMutationVersion += 1;
    observer?.disconnect();
    let elements;
    try {
      elements = candidates.map((el, index) => {
      const id = "el_" + index;
      el.setAttribute("data-ab-element-id", id);
      const rect = el.getBoundingClientRect();
      const inputType = el.tagName === "INPUT" ? (el.type || "text") : "";
      const inputRole = ({ checkbox:"checkbox",radio:"radio",button:"button",submit:"button",reset:"button",range:"slider",search:"searchbox" })[inputType] || "textbox";
      const role = el.getAttribute("role") || ({ H1:"heading",H2:"heading",H3:"heading",H4:"heading",H5:"heading",H6:"heading",BUTTON:"button",A:"link",INPUT:inputRole,TEXTAREA:"textbox",SELECT:"combobox",MAIN:"main",ARTICLE:"article",SECTION:"region" }[el.tagName] || "generic");
      const name = clean(el.getAttribute("aria-label") || el.labels?.[0]?.innerText || el.getAttribute("alt") || el.getAttribute("title") || el.getAttribute("placeholder") || el.innerText);
      const tag = el.tagName.toLowerCase();
      return { elementId: id, role, accessibleName: name, visibleText: clean(el.innerText, 300), visibility: "visible",
        disabled: Boolean(el.disabled || el.getAttribute("aria-disabled") === "true"),
        bounds: { x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.width), height: Math.round(rect.height) },
        metadata: { tag, inputType: tag === "input" ? inputType : undefined, fontSize: getComputedStyle(el).fontSize } };
      });
    } finally {
      observer?.observe(document.documentElement, { subtree: true, childList: true, attributes: true, characterData: true });
    }
    const headings = candidates.filter(el => /^H[1-6]$/.test(el.tagName)).slice(0, 40).map(el => clean(el.innerText, 200));
    const sections = candidates.filter(el => ["MAIN", "ARTICLE", "SECTION"].includes(el.tagName)).slice(0, 30).map(el => ({ role: el.getAttribute("role") || el.tagName.toLowerCase(), name: clean(el.getAttribute("aria-label") || el.querySelector("h1,h2,h3")?.innerText, 200) }));
    const textWalker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const textParts = [];
    let scannedText = 0;
    let textNode;
    let textLength = 0;
    while ((textNode = textWalker.nextNode()) && scannedText < maxScan && textLength < ${MAX_TEXT}) {
      scannedText += 1;
      const parent = textNode.parentElement;
      if (!parent || parent.closest("input,textarea,select,option,[contenteditable=true]") || !visible(parent)) continue;
      const part = textNode.nodeValue.slice(0, ${MAX_TEXT} - textLength + 256).trim();
      if (part) { const clipped = part.slice(0, ${MAX_TEXT} - textLength); textParts.push(clipped); textLength += clipped.length; }
    }
    const crossOriginIframes = [...document.querySelectorAll("iframe")].some((frame) => {
      try { return new URL(frame.src || "", location.href).origin !== location.origin; } catch { return true; }
    });
    const summary = clean(textParts.join(" "), ${MAX_TEXT});
    return { url: location.href, origin: location.origin, title: clean(document.title, 500),
      viewport: { width: innerWidth, height: innerHeight }, scroll: { x: scrollX, y: scrollY },
      elements, headings, sections, contentSummary: summary, crossOriginIframes };
  })()`);
  } catch (error) {
    if (!error.code) error.code = "SNAPSHOT_FAILED";
    throw error;
  }
  if (!validObject(raw) || !Array.isArray(raw.elements) || !Array.isArray(raw.sections) || !Array.isArray(raw.headings) || typeof raw.contentSummary !== "string" || typeof raw.crossOriginIframes !== "boolean") {
    throw Object.assign(new Error("The page returned an invalid snapshot."), { code: "SNAPSHOT_FAILED", retryable: true });
  }
  tab.elementIds = new Map(raw.elements.map((element) => [element.elementId, tab.pageRevision]));
  return {
    schemaVersion: 1, snapshotId, tabId: tab.id, pageRevision: tab.pageRevision,
    url: redactUrl(raw.url), origin: raw.origin, title: raw.title, viewport: raw.viewport, scroll: raw.scroll,
    elements: raw.elements, sections: raw.sections, contentSummary: raw.contentSummary,
    headings: raw.headings, pageMetadata: { loading: tab.view.webContents.isLoading(), crossOriginIframes: raw.crossOriginIframes },
  };
}

function validatePlan(plan) {
  requireKeys(plan, ["schemaVersion", "planId", "requestId", "tabId", "pageRevision", "summary", "actions", "confidence", "warnings", "suggestedScope", "status"]);
  if (plan.schemaVersion !== 1 || typeof plan.planId !== "string" || !plan.planId || typeof plan.requestId !== "string" || !plan.requestId || typeof plan.tabId !== "string" || !plan.tabId || !Number.isInteger(plan.pageRevision) || !Array.isArray(plan.actions) || plan.actions.length < 1 || plan.actions.length > 20 || typeof plan.summary !== "string" || plan.summary.length > 1000 || !["high", "medium", "low"].includes(plan.confidence) || !Array.isArray(plan.warnings) || plan.warnings.length > 30 || !plan.warnings.every((warning) => typeof warning === "string" && warning.length <= 500) || !["page", "website", "global", "none"].includes(plan.suggestedScope) || plan.status !== "ready") throw commandError("INVALID_PLAN", "Invalid adaptation plan envelope.");
  const tab = tabs.get(plan.tabId);
  if (!tab || tab.id !== activeTabId || tab.pageRevision !== plan.pageRevision) throw Object.assign(new Error("Plan targets a stale page revision"), { code: "STALE_PAGE_REVISION" });
  for (const action of plan.actions) {
    requireKeys(action, ["actionId", "type", "parameters", "reason", "reversible"], ["targetElementIds"]);
    if (!ACTION_KINDS.has(action.type)) throw Object.assign(new Error("Unsupported adaptation action"), { code: "UNSUPPORTED_ACTION" });
    if (!validObject(action.parameters) || typeof action.actionId !== "string" || !action.actionId || action.actionId.length > 120 || typeof action.reason !== "string" || !action.reason || action.reason.length > 500 || action.reversible !== true) throw commandError("INVALID_PLAN", "Invalid or non-reversible adaptation action.");
    if (action.targetElementIds !== undefined && (!Array.isArray(action.targetElementIds) || action.targetElementIds.length > 100)) throw new Error("targetElementIds must be an array of at most 100 identifiers");
    const params = action.parameters;
    switch (action.type) {
      case "set_text_scale":
        requireKeys(params, ["scale"]);
        if (!Number.isFinite(params.scale) || params.scale < 1 || params.scale > 2.5) throw commandError("INVALID_PARAMETERS", "Text scale must be between 1 and 2.5.");
        break;
      case "set_spacing":
        requireKeys(params, [], ["lineHeight", "letterSpacing"]);
        if (!Object.keys(params).length || (params.lineHeight !== undefined && (!Number.isFinite(params.lineHeight) || params.lineHeight < 1 || params.lineHeight > 2.5)) || (params.letterSpacing !== undefined && (!Number.isFinite(params.letterSpacing) || params.letterSpacing < 0 || params.letterSpacing > 0.2))) throw commandError("INVALID_PARAMETERS", "Spacing parameters are out of bounds.");
        break;
      case "set_contrast":
        requireKeys(params, ["level"]);
        if (!["high", "soft"].includes(params.level)) throw commandError("INVALID_PARAMETERS", "Contrast level must be high or soft.");
        break;
      case "set_color_filter":
        requireKeys(params, ["filter"]);
        if (!["grayscale", "warm", "cool", "invert"].includes(params.filter)) throw commandError("INVALID_PARAMETERS", "Unsupported color filter.");
        break;
      case "reduce_motion":
      case "enlarge_targets":
      case "reading_mode":
        requireKeys(params, ["enabled"]);
        if (typeof params.enabled !== "boolean") throw commandError("INVALID_PARAMETERS", "enabled must be a boolean.");
        break;
      case "hide_regions":
      case "focus_elements":
        requireKeys(params, []);
        if (!action.targetElementIds?.length) throw commandError("INVALID_PARAMETERS", `${action.type} requires target element identifiers.`);
        break;
    }
    for (const id of action.targetElementIds || []) {
      if (typeof id !== "string" || tab.elementIds.get(id) !== plan.pageRevision) throw Object.assign(new Error("Target element identifier is stale or unknown"), { code: "TARGET_NOT_FOUND" });
    }
  }
  return tab;
}

async function restoreFocus(tab, focusToken) {
  const token = JSON.stringify(focusToken);
  await executePageScript(tab, `(() => {
    const previous=window.__abFocusUndo?.[${token}];
    if(!previous)return false;
    if(previous.prior?.isConnected) previous.prior.focus?.({preventScroll:true});
    window.scrollTo(previous.x,previous.y);
    delete window.__abFocusUndo[${token}];
    return true;
  })()`);
}

register("ping", () => ({ ok: true, source: "electron", contractVersion: 1 }));
register("get-browser-state", () => ({ schemaVersion: 1, activeTabId, developmentFixtureEnabled: !app.isPackaged && process.env.ACCESSIBLE_BROWSER_DEVELOPMENT === "1", tabs: [...tabs.values()].map((tab) => ({ tabId: tab.id, url: redactUrl(tab.view.webContents.getURL()), title: tab.view.webContents.getTitle(), loading: tab.view.webContents.isLoading() })) }));
register("get-page-snapshot", getPageSnapshot);
register("request-adaptation", async (request) => {
  requireKeys(request, ["schemaVersion", "requestId", "tabId", "pageRevision", "userRequest", "activeProfile", "page", "applicableRules", "mode"]);
  if (request.schemaVersion !== 1 || typeof request.requestId !== "string" || request.requestId.length > 120 || !["deterministic", "llm"].includes(request.mode) || request.tabId !== activeTabId || !Number.isInteger(request.pageRevision) || typeof request.userRequest !== "string" || request.userRequest.length > 1000 || !validObject(request.activeProfile) || !validObject(request.page) || !Array.isArray(request.applicableRules) || request.applicableRules.length > 100) throw new Error("Invalid adaptation request");
  const tab = getActiveTab();
  await pageState(tab);
  if (request.page.pageRevision !== request.pageRevision || request.page.tabId !== request.tabId || tab.pageRevision !== request.pageRevision) throw Object.assign(new Error("Request targets a stale page revision"), { code: "STALE_PAGE_REVISION" });
  return { schemaVersion: 1, planId: makeId("plan"), requestId: request.requestId, tabId: request.tabId, pageRevision: request.pageRevision, status: "rejected", summary: "Adaptation planning belongs to Jac; Electron accepts only a validated plan to apply.", actions: [], confidence: "high", warnings: ["Call the Jac planner, then pass its validated plan to applyAdaptationPlan."], suggestedScope: "none" };
});
register("apply-adaptation-plan", async (plan) => {
  let tab;
  try {
    tab = validatePlan(plan);
  } catch (error) {
    if (!error.code) error.code = "INVALID_PLAN";
    throw error;
  }
  await pageState(tab);
  if (tab.pageRevision !== plan.pageRevision) throw Object.assign(new Error("Page changed after the plan was created"), { code: "STALE_PAGE_REVISION" });
  const applied = [];
  try {
    for (const action of plan.actions) {
      if (tab.pageRevision !== plan.pageRevision) throw Object.assign(new Error("Page changed while applying the plan"), { code: "STALE_PAGE_REVISION" });
      const ids = action.targetElementIds || [];
      const selector = ids.map((id) => `[data-ab-element-id="${id}"]`).join(",");
      let css = "";
      const params = action.parameters;
      switch (action.type) {
        case "set_text_scale": css = selector ? `${selector}{font-size:calc(1em * ${params.scale})!important}` : `html{font-size:calc(100% * ${params.scale})!important}body{font-size:1em!important}`; break;
        case "set_spacing": css = `${selector || "body"}{${params.lineHeight === undefined ? "" : `line-height:${params.lineHeight}!important;`}${params.letterSpacing === undefined ? "" : `letter-spacing:${params.letterSpacing}em!important;`}}`; break;
        case "set_contrast": css = `html{--ab-contrast:${params.level === "high" ? 1.45 : 1.1};filter:contrast(var(--ab-contrast,1)) var(--ab-color-filter,none)!important}`; break;
        case "set_color_filter": {
          const filter = { grayscale: "grayscale(1)", warm: "sepia(.35)", cool: "hue-rotate(12deg)", invert: "invert(1) hue-rotate(180deg)" }[params.filter];
          css = `html{--ab-color-filter:${filter};filter:contrast(var(--ab-contrast,1)) var(--ab-color-filter,none)!important}`; break;
        }
        case "reduce_motion": css = params.enabled ? "*,*::before,*::after{scroll-behavior:auto!important;animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important}" : "*,*::before,*::after{scroll-behavior:revert!important;animation-duration:revert!important;animation-iteration-count:revert!important;transition-duration:revert!important}"; break;
        case "enlarge_targets": css = params.enabled ? "button,a[href],input,select,textarea,[role=button]{min-width:2.75rem!important;min-height:2.75rem!important;padding:.5rem!important}" : "button,a[href],input,select,textarea,[role=button]{min-width:revert!important;min-height:revert!important;padding:revert!important}"; break;
        case "hide_regions": css = `${selector}{display:none!important;visibility:hidden!important}`; break;
        case "reading_mode": css = params.enabled ? "body{max-width:75ch!important;margin-inline:auto!important;line-height:1.7!important;padding-inline:1rem!important}" : "body{max-width:revert!important;margin-inline:revert!important;line-height:revert!important;padding-inline:revert!important}"; break;
        case "focus_elements": {
          const focusToken = makeId("focus");
          const safeIds = JSON.stringify(ids);
          await executePageScript(tab, `(() => {
            const ids=${safeIds};
            const target=document.querySelector('[data-ab-element-id="'+ids[0]+'"]');
            if(!target) throw new Error("Target not found");
            const prior=document.activeElement;
            const x=scrollX,y=scrollY;
            target.focus?.({preventScroll:true});
            if(document.activeElement!==target) throw new Error("Target cannot receive keyboard focus");
            window.__abFocusUndo=window.__abFocusUndo||{};
            window.__abFocusUndo[${JSON.stringify(focusToken)}]={prior,x,y};
            return true;
          })()`);
          applied.push({ type: action.type, focusToken });
          continue;
        }
      }
      const key = await tab.view.webContents.insertCSS(css, { cssOrigin: "user" });
      applied.push({ key, css, type: action.type });
    }
    if (tab.pageRevision !== plan.pageRevision) throw Object.assign(new Error("Page changed while applying the plan"), { code: "STALE_PAGE_REVISION" });
  } catch (error) {
    const rollbackErrors = [];
    for (const item of applied.reverse()) {
      if (item.key) {
        try { await tab.view.webContents.removeInsertedCSS(item.key); } catch (rollbackError) { rollbackErrors.push(rollbackError); }
      }
      if (item.focusToken) {
        try { await restoreFocus(tab, item.focusToken); } catch (rollbackError) { rollbackErrors.push(rollbackError); }
      }
    }
    const code = error.code === "STALE_PAGE_REVISION" || error.code === "TARGET_NOT_FOUND" ? error.code : "APPLY_FAILED";
    const rollbackMessage = rollbackErrors.length ? " Rollback could not fully remove every applied change." : "";
    throw Object.assign(new Error(`Adaptation rolled back: ${error.message}.${rollbackMessage}`), { code });
  }
  const undoToken = makeId("undo");
  if (tab.lastUndoToken) undoHistory.delete(tab.lastUndoToken);
  undoHistory.set(undoToken, { tabId: tab.id, pageRevision: tab.pageRevision, applied });
  tab.lastUndoToken = undoToken;
  return { status: "completed", planId: plan.planId, undoToken, result: `Applied ${applied.length} accessibility action${applied.length === 1 ? "" : "s"}.` };
});
register("undo-adaptation", async (token) => {
  requireKeys(token, ["undoToken"]);
  const entry = undoHistory.get(token.undoToken);
  const tab = entry && tabs.get(entry.tabId);
  if (tab) await pageState(tab);
  if (!entry || !tab || token.undoToken !== tab.lastUndoToken || tab.pageRevision !== entry.pageRevision) throw Object.assign(new Error("Undo token is stale or unknown"), { code: "UNDO_FAILED" });
  try {
    for (const item of [...entry.applied].reverse()) {
      if (item.key) await tab.view.webContents.removeInsertedCSS(item.key);
      if (item.focusToken) await restoreFocus(tab, item.focusToken);
    }
  } catch (error) {
    undoHistory.delete(token.undoToken);
    tab.lastUndoToken = undefined;
    bumpRevision(tab, "undo-failed");
    throw commandError("UNDO_FAILED", `Undo could not complete safely: ${error.message}`);
  }
  undoHistory.delete(token.undoToken);
  tab.lastUndoToken = undefined;
  bumpRevision(tab, "undo");
  return { status: "completed", result: "The latest adaptation was undone." };
});
register("execute-browser-command", async (command) => {
  const validation = validateBrowserCommand(command);
  if (validation.cancelled) return { status: "cancelled", requestId: command.requestId, result: "Closing a tab requires confirmation." };
  const jacValidation = await callJac("forward_browser_command", { command });
  if (!jacValidation?.ok) return jacValidation;
  const tab = tabs.get(command.tabId);
  const args = command.arguments;
  try {
    if (!tab) throw Object.assign(new Error("Browser command targets an unknown tab"), { code: "TARGET_NOT_FOUND" });
    switch (command.kind) {
      case "new_tab": {
        requireKeys(args, [], ["url"]);
        const next = createTab(args.url ? safeUrl(args.url) : DEFAULT_URL);
        return { status: "completed", requestId: command.requestId, tabId: next.id };
      }
      case "close_tab":
        requireKeys(args, []);
        if (!command.requiresConfirmation) return { status: "cancelled", requestId: command.requestId, result: "Closing a tab requires confirmation." };
        if (!tab) throw new Error("Tab not found");
        tab.view.webContents.close(); window.contentView.removeChildView(tab.view); tabs.delete(tab.id);
        if (tabs.size === 0) createTab(); else { activeTabId = [...tabs.keys()][0]; layoutViews(); }
        return { status: "completed", requestId: command.requestId, tabId: activeTabId };
      case "switch_tab":
        requireKeys(args, ["tabId"]);
        if (!tabs.has(args.tabId)) throw new Error("Tab not found");
        activeTabId = args.tabId; layoutViews();
        return { status: "completed", requestId: command.requestId, tabId: activeTabId };
      case "back": requireKeys(args, []); if (!tab?.view.webContents.navigationHistory.canGoBack()) throw new Error("No previous page"); tab.view.webContents.navigationHistory.goBack(); break;
      case "forward": requireKeys(args, []); if (!tab?.view.webContents.navigationHistory.canGoForward()) throw new Error("No next page"); tab.view.webContents.navigationHistory.goForward(); break;
      case "reload": requireKeys(args, []); if (!tab) throw new Error("Tab not found"); tab.view.webContents.reload(); break;
      case "navigate": {
        requireKeys(args, ["url"]);
        const result = await navigate(tab, args.url);
        return { ...result, requestId: command.requestId };
      }
      case "scroll": {
        requireKeys(args, ["deltaY"], ["deltaX"]);
        if (!Number.isFinite(args.deltaY) || Math.abs(args.deltaY) > 2000 || (args.deltaX !== undefined && (!Number.isFinite(args.deltaX) || Math.abs(args.deltaX) > 1000))) throw new Error("Scroll distance is out of bounds");
        await executePageScript(tab, `window.scrollBy(${Math.round(args.deltaX || 0)},${Math.round(args.deltaY)})`); break;
      }
      case "zoom": {
        requireKeys(args, ["factor"]);
        if (!Number.isFinite(args.factor) || args.factor < 0.5 || args.factor > 2.5) throw new Error("Zoom factor must be between 0.5 and 2.5");
        tab.view.webContents.setZoomFactor(args.factor); break;
      }
      case "search": {
        requireKeys(args, ["searchType"], ["query", "elementId"]);
        if (args.searchType === "focus_field") {
          requireKeys(args, ["searchType", "elementId"]);
          await pageState(tab);
          if (typeof args.elementId !== "string" || tab.elementIds.get(args.elementId) !== tab.pageRevision) throw Object.assign(new Error("Search field identifier is stale or unknown"), { code: "TARGET_NOT_FOUND" });
          const elementId = JSON.stringify(args.elementId);
          await executePageScript(tab, `document.querySelector('[data-ab-element-id="'+${elementId}+'"]')?.focus?.({preventScroll:true})`);
          return { status: "completed", requestId: command.requestId, result: "Search field focused." };
        }
        requireKeys(args, ["searchType", "query"]);
        if (!["web", "page"].includes(args.searchType) || typeof args.query !== "string" || args.query.length > 300 || !args.query.trim()) throw new Error("Search requires web or page and 1 to 300 characters of text");
        if (args.searchType === "web") return { ...(await navigate(tab, `https://www.google.com/search?q=${encodeURIComponent(args.query)}`)), requestId: command.requestId };
        const query = JSON.stringify(args.query.trim());
        const found = await executePageScript(tab, `(() => { const q=${query}.toLocaleLowerCase(); const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_ELEMENT); let scanned=0,node; while((node=walker.nextNode())&&scanned<2500){scanned+=1;if(node.children.length===0&&node.textContent.toLocaleLowerCase().includes(q)){node.scrollIntoView({block:"center"});return true;}} return false; })()`);
        return { status: found ? "completed" : "rejected", requestId: command.requestId, result: found ? "Search result focused." : "No matching page text." };
      }
      case "read_page": requireKeys(args, []); return { status: "accepted", requestId: command.requestId, result: "Page reading is not available yet." };
      case "stop_reading": requireKeys(args, []); return { status: "completed", requestId: command.requestId, result: "No page reading was active." };
      default: throw Object.assign(new Error("Unsupported browser command"), { code: "UNSUPPORTED_ACTION" });
    }
    return { status: "completed", requestId: command.requestId, tabId: tab.id };
  } catch (error) {
    if (!error.code) error.code = "INVALID_PARAMETERS";
    return structuredError(error, command.requestId);
  }
});

function createWindow() {
  window = new BrowserWindow({
    width: 1360, height: 900, minWidth: 760, minHeight: 560,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"), contextIsolation: true,
      nodeIntegration: false, sandbox: true, webviewTag: false,
    },
  });
  window.webContents.on("will-navigate", (event, target) => {
    if (target !== pathToFileURL(path.join(__dirname, "placeholder.html")).href) event.preventDefault();
  });
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  window.webContents.on("will-attach-webview", (event) => event.preventDefault());
  window.on("resize", layoutViews);
  window.on("closed", () => {
    for (const tab of tabs.values()) tab.view.webContents.close();
    tabs.clear();
    undoHistory.clear();
    window = undefined;
  });
  window.webContents.on("did-finish-load", () => {
    if (tabs.size === 0) createTab();
    layoutViews();
  });
  // This local surface is runtime chrome; Jac remains the product UI and planner owner.
  void window.loadFile(path.join(__dirname, "placeholder.html")).catch((error) => {
    if (window && !window.isDestroyed()) console.error(`Unable to load browser shell: ${error.message}`);
  });
}

function createExperienceWindow() {
  experienceWindow = new BrowserWindow({
    width: 1080,
    height: 900,
    minWidth: 760,
    minHeight: 600,
    title: "AccessibleBrowser accessibility experience",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webviewTag: false,
    },
  });
  experienceWindow.webContents.on("will-navigate", (event, target) => {
    try {
      if (new URL(target).origin !== new URL(jacUiUrl).origin) event.preventDefault();
    } catch { event.preventDefault(); }
  });
  experienceWindow.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  experienceWindow.webContents.on("will-attach-webview", (event) => event.preventDefault());
  experienceWindow.on("closed", () => { experienceWindow = undefined; });
  void experienceWindow.loadURL(jacUiUrl).catch((error) => {
    if (experienceWindow && !experienceWindow.isDestroyed()) {
      console.error(`Unable to load Jac accessibility experience: ${error.message}`);
    }
  });
}

register("jac", async (request) => {
  requireKeys(request, ["operation"], ["payload"]);
  if (typeof request.operation !== "string" || !jacOperations.has(request.operation)) {
    throw bridgeError("INVALID_MESSAGE", "Jac operation is not allowlisted.");
  }
  return callJac(request.operation, request.payload || {});
});

app.whenReady().then(() => {
  createWindow();
  createExperienceWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});
app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });
