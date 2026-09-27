"""Public Jac RPC surface for the UI and Electron bridge.

Each endpoint creates a short-lived service around the caller's persistent
Jac graph root.  The service remains the only place that coordinates planning,
validation, explanation, and persistence; the wire format is the same
camelCase contract used by CONTRACTS.md.
"""

import from .core {
    AccessibilityProfile,
    AdaptationRequest,
    AdaptationPlan,
    BrowserCommand,
    CommandResult,
    PageSnapshot,
    PersistenceProposal,
    PlanExplanation,
    PlanResult,
    PreferenceRule
}
import from .persistence {
    PreferenceSaveResult,
    graph_load_store,
    applicable_preferences
}
import from .service { AdaptationService }

def api_service() -> AdaptationService {
    return AdaptationService(store=graph_load_store());
}

def:pub get_active_profile() -> AccessibilityProfile {
    return api_service().get_active_profile();
}

def:pub update_active_profile(profile: AccessibilityProfile) -> AccessibilityProfile {
    service = api_service();
    service.update_active_profile(profile);
    return service.get_active_profile();
}

def:pub get_applicable_preferences(origin: str, pageUrl: str) -> list[PreferenceRule] {
    return applicable_preferences(graph_load_store(), origin, pageUrl);
}

def:pub create_adaptation_request(
    requestId: str,
    userRequest: str,
    tabId: str,
    pageRevision: int,
    profile: AccessibilityProfile,
    page: PageSnapshot,
    mode: str = "deterministic"
) -> AdaptationRequest {
    return api_service().create_request(
        requestId,
        userRequest,
        tabId,
        pageRevision,
        profile,
        page,
        mode
    );
}

def:pub create_adaptation_plan(adaptation: AdaptationRequest) -> PlanResult {
    return api_service().create_plan(adaptation);
}

def:pub explain_adaptation_plan(plan: AdaptationPlan) -> PlanExplanation {
    return api_service().explain(plan);
}

def:pub record_apply_result(
    requestId: str,
    planId: str,
    result: str,
    undoToken: str
) -> bool {
    api_service().record_apply_result(requestId, planId, result, undoToken);
    return True;
}

def:pub propose_persistence(plan: AdaptationPlan) -> PersistenceProposal {
    return api_service().propose_save(plan);
}

def:pub save_approved_preference(
    rule: PreferenceRule,
    explicitlyApproved: bool
) -> PreferenceSaveResult {
    return api_service().save_approved_preference(rule, explicitlyApproved);
}

def:pub forward_browser_command(command: BrowserCommand) -> CommandResult {
    return api_service().forward_browser_command(command);
}
