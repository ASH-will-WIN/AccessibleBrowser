"""Bounded NVIDIA NIM planning adapter.

Only this module knows how to call the online model. The rest of Jac receives
typed plans and validates them before any bridge handoff.  The adapter uses the
standard library so the repository does not acquire a provider-specific SDK.
"""

import from .core {
    AccessibilityProfile,
    ElementSummary,
    AdaptationPlan,
    AdaptationRequest,
    PlanAction,
    PlanResult,
    validate_plan,
    validate_adaptation_request,
    contains_any,
    plan_error,
    deterministic_plan
}
import json;

::py::
import json
import os
import urllib.error
import urllib.request

def _ab_getenv(name):
    return os.environ.get(name, "")

def _ab_nim_plan(api_key, model, base_url, payload):
    system = (
        "You are an accessibility planning service. Return JSON only. "
        "Return exactly one JSON object with schemaVersion, planId, requestId, "
        "tabId, pageRevision, summary, confidence, warnings, suggestedScope, "
        "status, and actions. Copy requestId, tabId, and pageRevision exactly "
        "from the input. Use status ready when actions are present and noOp "
        "only when actions is empty. Each action must include actionId, type, "
        "parameters, reason, reversible:true, and targetElementIds. Each action "
        "must use only these type values: "
        "set_text_scale, set_spacing, set_contrast, set_color_filter, set_reading_font, "
        "reduce_motion, enlarge_targets, hide_regions, reading_mode, focus_elements. "
        "Use these parameter shapes only: set_text_scale {scale}; set_spacing "
        "{lineHeight,letterSpacing}; set_contrast {level:normal|high|soft}; "
        "set_color_filter {filter:none|grayscale|warm|cool|invert}; "
        "set_reading_font {font:default|reading}; reduce_motion, enlarge_targets, "
        "and reading_mode {enabled}; focus_elements and hide_regions use bounded "
        "targetElementIds and empty parameters. "
        "confidence must be exactly one of high, medium, or low. "
        "Never return JavaScript, CSS, selectors, shell commands, or browser commands. "
        "Use typed parameters, a reason, reversible=True, and targetElementIds only "
        "from the supplied snapshot."
    )
    request_body = {
        "model": model or "meta/llama-3.1-8b-instruct",
        "temperature": 0,
        "max_tokens": 2000,
        "chat_template_kwargs": {"enable_thinking": False},
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(payload, ensure_ascii=False)}
        ]
    }
    request = urllib.request.Request(
        base_url.rstrip("/") + "/chat/completions",
        data=json.dumps(request_body).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + api_key,
            "Content-Type": "application/json"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = json.loads(response.read(65_536).decode("utf-8"))
        content = raw["choices"][0]["message"]["content"]
        if not isinstance(content, str) or len(content) > 32_000:
            return {"ok": False, "error": "The model response was empty or too large."}
        if content.startswith("```"):
            content = content.strip().strip("`").replace("json\n", "", 1)
        return {"ok": True, "content": content}
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError, IndexError) as exc:
        return {"ok": False, "error": type(exc).__name__}
::py::

def profile_to_payload(profile: AccessibilityProfile) -> dict[str, any] {
    return {
        "textScale": profile.textScale,
        "spacing": profile.spacing,
        "contrast": profile.contrast,
        "colorFilter": profile.colorFilter,
        "reduceMotion": profile.reduceMotion,
        "enlargeTargets": profile.enlargeTargets,
        "readingFont": profile.readingFont,
        "voiceEnabled": profile.voiceEnabled
    };
}

def bounded_rule_value(value: any) -> any {
    if isinstance(value, str) { return value[:200]; }
    if isinstance(value, bool) { return value; }
    if isinstance(value, (int, float)) and value == value and abs(value) <= 1000 { return value; }
    return None;
}

def is_sensitive_element(element: ElementSummary) -> bool {
    role = element.role.lower();
    label = element.accessibleName.lower();
    return role in ["textbox", "searchbox", "combobox", "password"]
        or contains_any(label, ["password", "secret", "token", "api key", "credit card", "ssn"]);
}

def bounded_payload(request: AdaptationRequest) -> dict[str, any] {
    safeElements: list[dict[str, any]] = [];
    elementCount = 0;
    for element in request.page.elements {
        if elementCount >= 40 { break; }
        safeText = element.text[:300];
        if is_sensitive_element(element) { safeText = ""; }
        safeElements.append({
            "elementId": element.elementId,
            "role": element.role,
            "accessibleName": element.accessibleName[:200],
            "text": safeText,
            "visible": element.visible,
            "disabled": element.disabled,
            "bounds": {
                "x": element.bounds.get("x", 0),
                "y": element.bounds.get("y", 0),
                "width": element.bounds.get("width", 0),
                "height": element.bounds.get("height", 0)
            }
        });
        elementCount += 1;
    }
    safeRules: list[dict[str, any]] = [];
    ruleCount = 0;
    for rule in request.applicableRules {
        if ruleCount >= 20 { break; }
        safeRules.append({
            "setting": rule.setting,
            "value": bounded_rule_value(rule.value),
            "scope": rule.scope,
            "source": rule.source,
            "explicitlyApproved": rule.explicitlyApproved
        });
        ruleCount += 1;
    }
    return {
        "schemaVersion": request.schemaVersion,
        "requestId": request.requestId,
        "tabId": request.tabId,
        "pageRevision": request.pageRevision,
        "userRequest": request.userRequest[:1000],
        "activeProfile": profile_to_payload(request.activeProfile),
        "applicableRules": safeRules,
        "page": {
            "snapshotId": request.page.snapshotId,
            "url": request.page.url[:500],
            "origin": request.page.origin[:300],
            "title": request.page.title[:300],
            "viewport": {
                "width": request.page.viewport.get("width", 0),
                "height": request.page.viewport.get("height", 0)
            },
            "elements": safeElements,
            "sections": [{"role": section.role[:80], "name": section.name[:200]} for section in request.page.sections[:10]],
            "contentSummary": request.page.contentSummary[:2000]
        }
    };
}

def string_list(data: any, key: str) -> list[str] {
    output: list[str] = [];
    value = data.get(key, []);
    if isinstance(value, list) {
        for item in value {
            if isinstance(item, str) and len(item) <= 500 { output.append(item); }
        }
    }
    return output;
}

def model_plan_from_map(data: dict[str, any], request: AdaptationRequest) -> PlanResult {
    rawActions = data.get("actions");
    actions: list[PlanAction] = [];
    if not isinstance(rawActions, list) or len(rawActions) > 20 {
        return plan_error(request.requestId, "INVALID_PLAN", "Model actions must be an array.", False);
    }
    if data.get("schemaVersion", 1) is not None and not isinstance(data.get("schemaVersion", 1), int) {
        return plan_error(request.requestId, "INVALID_PLAN", "Model schemaVersion must be an integer.", False);
    }
    modelRequestId = data.get("requestId", request.requestId);
    modelTabId = data.get("tabId", request.tabId);
    modelRevision = data.get("pageRevision", request.pageRevision);
    if not isinstance(modelRequestId, str) or modelRequestId != request.requestId or not isinstance(modelTabId, str) or modelTabId != request.tabId or not isinstance(modelRevision, int) or modelRevision != request.pageRevision {
        return plan_error(request.requestId, "INVALID_PLAN", "Model plan metadata does not match the request.", False);
    }
    summaryValue = data.get("summary", "Prepared an accessibility adaptation plan.");
    confidenceValue = data.get("confidence", "medium");
    scopeValue = data.get("suggestedScope", "page");
    statusValue = data.get("status", "ready");
    if not isinstance(summaryValue, str) or len(summaryValue) > 1000 or not isinstance(confidenceValue, str) or not isinstance(scopeValue, str) or not isinstance(statusValue, str) {
        return plan_error(request.requestId, "INVALID_PLAN", "Model plan metadata has an invalid type or size.", False);
    }
    rawWarnings = data.get("warnings", []);
    if not isinstance(rawWarnings, list) or len(rawWarnings) > 30 {
        return plan_error(request.requestId, "INVALID_PLAN", "Model warnings must be a bounded array.", False);
    }
    for warning in rawWarnings {
        if not isinstance(warning, str) or len(warning) > 500 { return plan_error(request.requestId, "INVALID_PLAN", "Model warnings must be bounded strings.", False); }
    }
    actionNumber = 1;
    for rawAction in rawActions {
        if not isinstance(rawAction, dict) {
            return plan_error(request.requestId, "INVALID_PLAN", "Each model action must be an object.", False);
        }
        item = rawAction as dict[str, any];
        actionType = item.get("type", item.get("actionType", ""));
        if not isinstance(actionType, str) {
            return plan_error(request.requestId, "INVALID_PLAN", "Model action type must be a string.", False);
        }
        parameters = item.get("parameters", {});
        if not isinstance(parameters, dict) {
            return plan_error(request.requestId, "INVALID_PARAMETERS", "Model action parameters must be an object.", False);
        }
        actionId = item.get("actionId");
        reason = item.get("reason");
        reversible = item.get("reversible");
        if not isinstance(actionId, str) or not isinstance(reason, str) or not isinstance(reversible, bool) {
            return plan_error(request.requestId, "INVALID_PLAN", "Model action metadata has an invalid type.", False);
        }
        if len(actionId) == 0 or len(actionId) > 120 or reason.strip() == "" or len(reason) > 500 or not reversible {
            return plan_error(request.requestId, "INVALID_PLAN", "Model actions must be bounded, explained, and reversible.", False, actionId as str);
        }
        targetIds: list[str] = [];
        rawTargets = item.get("targetElementIds", []);
        if not isinstance(rawTargets, list) or len(rawTargets) > 100 {
            return plan_error(request.requestId, "INVALID_PLAN", "Model targetElementIds must be a bounded array.", False, actionId as str);
        }
        for target in rawTargets {
            if not isinstance(target, str) or target.strip() == "" or len(target) > 120 {
                return plan_error(request.requestId, "INVALID_PLAN", "Model target element IDs must be bounded strings.", False, actionId as str);
            }
            targetIds.append(target);
        }
        actions.append(PlanAction(
            actionId=actionId,
            type=actionType,
            parameters=parameters as dict[str, any],
            reason=reason,
            reversible=reversible,
            targetElementIds=targetIds
        ));
        actionNumber += 1;
    }
    plan = AdaptationPlan(
        schemaVersion=data.get("schemaVersion", 1) as int,
        planId=data.get("planId", "plan_" + request.requestId) as str,
        requestId=request.requestId,
        tabId=request.tabId,
        pageRevision=modelRevision as int,
        summary=summaryValue as str,
        actions=actions,
        confidence=confidenceValue as str,
        warnings=string_list(data, "warnings"),
        suggestedScope=scopeValue as str,
        status=statusValue as str
    );
    return validate_plan(plan, request);
}

def llm_plan(request: AdaptationRequest) -> PlanResult {
    apiKey = _ab_getenv("NVIDIA_API_KEY") as str;
    if apiKey == "" {
        return plan_error(request.requestId, "LLM_UNAVAILABLE", "NVIDIA_API_KEY is not configured.", True);
    }
    model = _ab_getenv("NVIDIA_NIM_MODEL") as str;
    baseUrl = _ab_getenv("NVIDIA_NIM_BASE_URL") as str;
    if baseUrl == "" { baseUrl = "https://integrate.api.nvidia.com/v1"; }
    response: any = _ab_nim_plan(apiKey, model, baseUrl, bounded_payload(request));
    responseMap = response as dict[str, any];
    if not (responseMap.get("ok", False) as bool) {
        return plan_error(request.requestId, "LLM_UNAVAILABLE", "The online planner could not be reached.", True);
    }
    content = responseMap.get("content", "");
    if not isinstance(content, str) {
        return plan_error(request.requestId, "INVALID_PLAN", "The model response was not text.", False);
    }
    parsed: any = {};
    try {
        parsed = json.loads(content);
    } except ValueError {
        return plan_error(request.requestId, "INVALID_PLAN", "The model response was not valid JSON.", False);
    }
    if not isinstance(parsed, dict) {
        return plan_error(request.requestId, "INVALID_PLAN", "The model response was not a JSON object.", False);
    }
    return model_plan_from_map(parsed as dict[str, any], request);
}

def create_adaptation_plan(request: AdaptationRequest) -> PlanResult {
    requestError = validate_adaptation_request(request);
    if requestError is not None { return PlanResult(ok=False, error=requestError); }
    if request.mode != "llm" {
        return deterministic_plan(request);
    }
    result = llm_plan(request);
    if result.ok { return result; }
    fallback = deterministic_plan(request);
    if fallback.ok and fallback.plan is not None {
        fallback.plan.warnings.append("The online planner was unavailable or returned an invalid plan (" + (result.error.message if result.error else "unknown validation error") + "); a deterministic local plan was used.");
        return fallback;
    }
    return result;
}
