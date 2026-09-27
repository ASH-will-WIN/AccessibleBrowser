"""Bounded OpenAI planning adapter.

Only this module knows how to call the online model.  The rest of Jac receives
typed plans and validates them before any bridge handoff.  The adapter uses the
standard library so the repository does not acquire a provider-specific SDK.
"""

import from .core {
    AccessibilityProfile,
    AdaptationPlan,
    AdaptationRequest,
    PlanAction,
    PlanResult,
    validate_plan,
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

def _ab_openai_plan(api_key, model, payload):
    system = (
        "You are an accessibility planning service. Return JSON only. "
        "Return an object with summary, confidence, warnings, suggestedScope, "
        "status, and actions. Each action must use only these type values: "
        "set_text_scale, set_spacing, set_contrast, set_color_filter, "
        "reduce_motion, enlarge_targets, hide_regions, reading_mode, focus_elements. "
        "Never return JavaScript, CSS, selectors, shell commands, or browser commands. "
        "Use typed parameters, a reason, reversible=True, and targetElementIds only "
        "from the supplied snapshot."
    )
    request_body = {
        "model": model or "gpt-4o-mini",
        "temperature": 0,
        "max_tokens": 1200,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(payload, ensure_ascii=False)}
        ]
    }
    request = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps(request_body).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + api_key,
            "Content-Type": "application/json"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = json.loads(response.read(1_000_000).decode("utf-8"))
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

def bounded_payload(request: AdaptationRequest) -> dict[str, any] {
    safeElements: list[dict[str, any]] = [];
    elementCount = 0;
    for element in request.page.elements {
        if elementCount >= 40 { break; }
        safeText = element.text;
        if element.role == "textbox" or "password" in element.accessibleName.lower() {
            safeText = "";
        }
        safeElements.append({
            "elementId": element.elementId,
            "role": element.role,
            "accessibleName": element.accessibleName[:200],
            "text": safeText[:300],
            "visible": element.visible,
            "disabled": element.disabled,
            "bounds": element.bounds
        });
        elementCount += 1;
    }
    safeRules: list[dict[str, any]] = [];
    for rule in request.applicableRules {
        safeRules.append({
            "setting": rule.setting,
            "value": rule.value,
            "scope": rule.scope,
            "source": rule.source,
            "explicitlyApproved": rule.explicitlyApproved
        });
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
            "viewport": request.page.viewport,
            "elements": safeElements,
            "sections": [{"role": section.role, "name": section.name[:200]} for section in request.page.sections[:20]],
            "contentSummary": request.page.contentSummary[:4000]
        }
    };
}

def string_list(data: any, key: str) -> list[str] {
    output: list[str] = [];
    value = data.get(key, []);
    if isinstance(value, list) {
        for item in value {
            if isinstance(item, str) { output.append(item); }
        }
    }
    return output;
}

def model_plan_from_map(data: dict[str, any], request: AdaptationRequest) -> PlanResult {
    rawActions = data.get("actions", []);
    actions: list[PlanAction] = [];
    if not isinstance(rawActions, list) {
        return plan_error(request.requestId, "INVALID_PLAN", "Model actions must be an array.", False);
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
        actionId = item.get("actionId", "model_action_" + str(actionNumber));
        reason = item.get("reason", "Suggested by the accessibility planner.");
        reversible = item.get("reversible", True);
        if not isinstance(actionId, str) or not isinstance(reason, str) or not isinstance(reversible, bool) {
            return plan_error(request.requestId, "INVALID_PLAN", "Model action metadata has an invalid type.", False);
        }
        targetIds: list[str] = [];
        rawTargets = item.get("targetElementIds", []);
        if isinstance(rawTargets, list) {
            for target in rawTargets {
                if isinstance(target, str) { targetIds.append(target); }
            }
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
        pageRevision=data.get("pageRevision", request.pageRevision) as int,
        summary=data.get("summary", "Prepared an accessibility adaptation plan.") as str,
        actions=actions,
        confidence=data.get("confidence", "medium") as str,
        warnings=string_list(data, "warnings"),
        suggestedScope=data.get("suggestedScope", "page") as str,
        status=data.get("status", "ready") as str
    );
    return validate_plan(plan, request);
}

def llm_plan(request: AdaptationRequest) -> PlanResult {
    apiKey = _ab_getenv("OPENAI_API_KEY") as str;
    if apiKey == "" {
        return plan_error(request.requestId, "LLM_UNAVAILABLE", "OPENAI_API_KEY is not configured.", True);
    }
    model = _ab_getenv("OPENAI_MODEL") as str;
    response: any = _ab_openai_plan(apiKey, model, bounded_payload(request));
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
    if request.mode != "llm" {
        return deterministic_plan(request);
    }
    result = llm_plan(request);
    if result.ok { return result; }
    fallback = deterministic_plan(request);
    if fallback.ok and fallback.plan is not None {
        fallback.plan.warnings.append("The online planner was unavailable; a deterministic local plan was used.");
        return fallback;
    }
    return result;
}
