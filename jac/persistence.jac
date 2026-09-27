"""Local-first preference storage and scope resolution.

PreferenceProfileNode/PreferenceRuleNode are the Jac graph model for the
durable concepts.  PreferenceStore is the small repository boundary used by
the planner and service.  Tests may use its atomic JSON adapter, while served
endpoints use the persistent graph rooted at the current user's `root`.
"""

import from .core {
    AccessibilityProfile,
    ApplyRecord,
    PreferenceRule,
    StructuredError
}
import json;

::py::
import json
import os
from datetime import datetime, timezone

def _ab_now_iso():
    return datetime.now(timezone.utc).isoformat()

def _ab_load_json(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            value = json.load(handle)
            return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}

def _ab_save_json(path, payload):
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
    os.replace(temporary, path)
::py::

node PreferenceProfileNode {
    has profileId: str,
        textScale: float = 1.0,
        spacing: str = "normal",
        contrast: str = "normal",
        colorFilter: str = "none",
        reduceMotion: bool = False,
        enlargeTargets: bool = False,
        readingFont: str = "default",
        voiceEnabled: bool = False;
}

node PreferenceRuleNode {
    has setting: str,
        scope: str,
        source: str,
        explicitlyApproved: bool,
        createdAt: str,
        updatedAt: str,
        origin: str = "",
        pageUrl: str = "",
        valueJson: str = "";
}

edge ProfileHasRule: PreferenceProfileNode --> PreferenceRuleNode {
    has linkedAt: str;
}

node PreferenceApplyNode {
    has requestId: str,
        planId: str,
        result: str,
        undoToken: str,
        createdAt: str;
}

edge ProfileHasApply: PreferenceProfileNode --> PreferenceApplyNode {
    has linkedAt: str;
}

obj PreferenceStore {
    has filePath: str,
        graphBacked: bool = False,
        activeProfile: AccessibilityProfile = AccessibilityProfile(),
        rules: list[PreferenceRule] = [],
        history: list[ApplyRecord] = [];
}

obj PreferenceSaveResult {
    has ok: bool,
        error: StructuredError | None = None;
}

def now_iso() -> str {
    return _ab_now_iso() as str;
}

def new_store(filePath: str) -> PreferenceStore {
    return PreferenceStore(filePath=filePath);
}

def new_graph_store() -> PreferenceStore {
    return PreferenceStore(filePath="", graphBacked=True);
}

def profile_to_map(profile: AccessibilityProfile) -> dict[str, any] {
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

def profile_from_map(data: dict[str, any]) -> AccessibilityProfile {
    return AccessibilityProfile(
        textScale=data.get("textScale", 1.0) as float,
        spacing=data.get("spacing", "normal") as str,
        contrast=data.get("contrast", "normal") as str,
        colorFilter=data.get("colorFilter", "none") as str,
        reduceMotion=data.get("reduceMotion", False) as bool,
        enlargeTargets=data.get("enlargeTargets", False) as bool,
        readingFont=data.get("readingFont", "default") as str,
        voiceEnabled=data.get("voiceEnabled", False) as bool
    );
}

def rule_to_map(rule: PreferenceRule) -> dict[str, any] {
    return {
        "setting": rule.setting,
        "value": rule.value,
        "scope": rule.scope,
        "origin": rule.origin,
        "pageUrl": rule.pageUrl,
        "source": rule.source,
        "explicitlyApproved": rule.explicitlyApproved,
        "createdAt": rule.createdAt,
        "updatedAt": rule.updatedAt
    };
}

def record_to_map(record: ApplyRecord) -> dict[str, any] {
    return {
        "requestId": record.requestId,
        "planId": record.planId,
        "result": record.result,
        "undoToken": record.undoToken,
        "createdAt": record.createdAt
    };
}

def store_to_map(store: PreferenceStore) -> dict[str, any] {
    return {
        "activeProfile": profile_to_map(store.activeProfile),
        "rules": [rule_to_map(rule) for rule in store.rules],
        "history": [record_to_map(record) for record in store.history]
    };
}

def rule_from_map(data: dict[str, any]) -> PreferenceRule {
    return PreferenceRule(
        setting=data.get("setting", "") as str,
        value=data.get("value"),
        scope=data.get("scope", "global") as str,
        source=data.get("source", "manual") as str,
        explicitlyApproved=data.get("explicitlyApproved", False) as bool,
        createdAt=data.get("createdAt", "") as str,
        updatedAt=data.get("updatedAt", "") as str,
        origin=data.get("origin", "") as str,
        pageUrl=data.get("pageUrl", "") as str
    );
}

def load_store(store: PreferenceStore) {
    raw: any = _ab_load_json(store.filePath);
    if not isinstance(raw, dict) { return; }
    data = raw as dict[str, any];
    profileData = data.get("activeProfile", {});
    if isinstance(profileData, dict) {
        store.activeProfile = profile_from_map(profileData as dict[str, any]);
    }
    rawRules = data.get("rules", []);
    if isinstance(rawRules, list) {
        store.rules = [];
        for rawRule in rawRules {
            if isinstance(rawRule, dict) {
                store.rules.append(rule_from_map(rawRule as dict[str, any]));
            }
        }
    }
    rawHistory = data.get("history", []);
    if isinstance(rawHistory, list) {
        store.history = [];
        for rawRecord in rawHistory {
            if isinstance(rawRecord, dict) {
                recordData = rawRecord as dict[str, any];
                store.history.append(ApplyRecord(
                    requestId=recordData.get("requestId", "") as str,
                    planId=recordData.get("planId", "") as str,
                    result=recordData.get("result", "") as str,
                    undoToken=recordData.get("undoToken", "") as str,
                    createdAt=recordData.get("createdAt", "") as str
                ));
            }
        }
    }
}

def save_store(store: PreferenceStore) {
    _ab_save_json(store.filePath, store_to_map(store));
}

def graph_profile_node() -> PreferenceProfileNode {
    profiles: list[PreferenceProfileNode] = [root -->][?:PreferenceProfileNode];
    if len(profiles) > 0 {
        return profiles[0];
    }
    profile = (root ++> PreferenceProfileNode(profileId="default")) as PreferenceProfileNode;
    return profile;
}

def profile_from_node(profile: PreferenceProfileNode) -> AccessibilityProfile {
    return AccessibilityProfile(
        textScale=profile.textScale,
        spacing=profile.spacing,
        contrast=profile.contrast,
        colorFilter=profile.colorFilter,
        reduceMotion=profile.reduceMotion,
        enlargeTargets=profile.enlargeTargets,
        readingFont=profile.readingFont,
        voiceEnabled=profile.voiceEnabled
    );
}

def rule_from_node(rule: PreferenceRuleNode) -> PreferenceRule {
    return PreferenceRule(
        setting=rule.setting,
        value=value_from_json(rule.valueJson),
        scope=rule.scope,
        source=rule.source,
        explicitlyApproved=rule.explicitlyApproved,
        createdAt=rule.createdAt,
        updatedAt=rule.updatedAt,
        origin=rule.origin,
        pageUrl=rule.pageUrl
    );
}

def value_to_json(value: any) -> str {
    return json.dumps(value, ensure_ascii=False) as str;
}

def value_from_json(valueJson: str) -> any {
    try {
        return json.loads(valueJson);
    } except ValueError {
        return valueJson;
    }
}

def graph_load_store() -> PreferenceStore {
    profile = graph_profile_node();
    store = new_graph_store();
    store.activeProfile = profile_from_node(profile);
    store.rules = [rule_from_node(rule) for rule in [profile -->][?:PreferenceRuleNode]];
    store.history = [
        ApplyRecord(
            requestId=record.requestId,
            planId=record.planId,
            result=record.result,
            undoToken=record.undoToken,
            createdAt=record.createdAt
        )
        for record in [profile -->][?:PreferenceApplyNode]
    ];
    return store;
}

def graph_update_profile(profile: AccessibilityProfile) {
    profileNode = graph_profile_node();
    profileNode.textScale = profile.textScale;
    profileNode.spacing = profile.spacing;
    profileNode.contrast = profile.contrast;
    profileNode.colorFilter = profile.colorFilter;
    profileNode.reduceMotion = profile.reduceMotion;
    profileNode.enlargeTargets = profile.enlargeTargets;
    profileNode.readingFont = profile.readingFont;
    profileNode.voiceEnabled = profile.voiceEnabled;
}

def graph_save_rule(rule: PreferenceRule) {
    profile = graph_profile_node();
    matching = [
        item for item in [profile -->][?:PreferenceRuleNode]
        if item.setting == rule.setting
        and item.scope == rule.scope
        and item.origin == rule.origin
        and item.pageUrl == rule.pageUrl
    ];
    if len(matching) > 0 {
        existing = matching[0];
        existing.valueJson = value_to_json(rule.value);
        existing.source = rule.source;
        existing.explicitlyApproved = rule.explicitlyApproved;
        existing.createdAt = rule.createdAt;
        existing.updatedAt = rule.updatedAt;
        return;
    }
    created = PreferenceRuleNode(
        setting=rule.setting,
        valueJson=value_to_json(rule.value),
        scope=rule.scope,
        source=rule.source,
        explicitlyApproved=rule.explicitlyApproved,
        createdAt=rule.createdAt,
        updatedAt=rule.updatedAt,
        origin=rule.origin,
        pageUrl=rule.pageUrl
    );
    profile +>:ProfileHasRule(linkedAt=now_iso()):+> created;
}

def graph_record_apply(record: ApplyRecord) {
    profile = graph_profile_node();
    created = PreferenceApplyNode(
        requestId=record.requestId,
        planId=record.planId,
        result=record.result,
        undoToken=record.undoToken,
        createdAt=record.createdAt
    );
    profile +>:ProfileHasApply(linkedAt=now_iso()):+> created;
}

def update_active_profile(store: PreferenceStore, profile: AccessibilityProfile) {
    store.activeProfile = profile;
    if store.graphBacked {
        graph_update_profile(profile);
        return;
    }
    save_store(store);
}

def make_rule(setting: str, value: any, scope: str, source: str, origin: str = "", pageUrl: str = "") -> PreferenceRule {
    timestamp = now_iso();
    return PreferenceRule(
        setting=setting,
        value=value,
        scope=scope,
        source=source,
        explicitlyApproved=True,
        createdAt=timestamp,
        updatedAt=timestamp,
        origin=origin,
        pageUrl=pageUrl
    );
}

def save_preference(store: PreferenceStore, rule: PreferenceRule, explicitlyApproved: bool) -> PreferenceSaveResult {
    if not explicitlyApproved or not rule.explicitlyApproved {
        return PreferenceSaveResult(
            ok=False,
            error=StructuredError(
                requestId="",
                code="PERMISSION_DENIED",
                message="Preferences are saved only after explicit approval.",
                retryable=False
            )
        );
    }
    if rule.scope not in ["page", "website", "global"] {
        return PreferenceSaveResult(
            ok=False,
            error=StructuredError(
                requestId="",
                code="INVALID_PARAMETERS",
                message="Preference scope must be page, website, or global.",
                retryable=False
            )
        );
    }
    replaced = False;
    for index in range(len(store.rules)) {
        existing = store.rules[index];
        if existing.setting == rule.setting and existing.scope == rule.scope and existing.origin == rule.origin and existing.pageUrl == rule.pageUrl {
            store.rules[index] = rule;
            replaced = True;
        }
    }
    if not replaced { store.rules.append(rule); }
    if store.graphBacked {
        graph_save_rule(rule);
    } else {
        save_store(store);
    }
    return PreferenceSaveResult(ok=True);
}

def rule_specificity(rule: PreferenceRule, origin: str, pageUrl: str) -> int {
    if rule.scope == "page" and rule.pageUrl == pageUrl and pageUrl != "" { return 3; }
    if rule.scope == "website" and rule.origin == origin and origin != "" { return 2; }
    if rule.scope == "global" { return 1; }
    return 0;
}

def applicable_preferences(store: PreferenceStore, origin: str, pageUrl: str) -> list[PreferenceRule] {
    selected: dict[str, PreferenceRule] = {};
    scores: dict[str, int] = {};
    for rule in store.rules {
        if not rule.explicitlyApproved { continue; }
        score = rule_specificity(rule, origin, pageUrl);
        if score == 0 { continue; }
        previous = scores.get(rule.setting, 0);
        if score >= previous {
            selected[rule.setting] = rule;
            scores[rule.setting] = score;
        }
    }
    return [rule for rule in selected.values()];
}

def record_apply(store: PreferenceStore, requestId: str, planId: str, result: str, undoToken: str) {
    record = ApplyRecord(
        requestId=requestId,
        planId=planId,
        result=result,
        undoToken=undoToken,
        createdAt=now_iso()
    );
    store.history.append(record);
    if store.graphBacked {
        graph_record_apply(record);
    } else {
        save_store(store);
    }
}
