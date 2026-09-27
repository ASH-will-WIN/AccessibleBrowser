"""Stable Jac service surface for the UI and typed Electron bridge."""

import from .core {
    AccessibilityProfile,
    AdaptationRequest,
    AdaptationPlan,
    PageSnapshot,
    PreferenceRule,
    PersistenceProposal,
    PlanExplanation,
    PlanResult,
    BrowserCommand,
    CommandResult,
    create_adaptation_request,
    propose_persistence,
    explain_plan,
    validate_browser_command
}
import from .persistence {
    PreferenceStore,
    PreferenceSaveResult,
    applicable_preferences,
    record_apply,
    save_preference,
    update_active_profile
}
import from .provider { create_adaptation_plan }

obj AdaptationService {
    has store: PreferenceStore;

    def get_active_profile() -> AccessibilityProfile {
        return self.store.activeProfile;
    }

    def update_active_profile(profile: AccessibilityProfile) {
        update_active_profile(self.store, profile);
    }

    def get_applicable_preferences(origin: str, pageUrl: str) -> list[PreferenceRule] {
        return applicable_preferences(self.store, origin, pageUrl);
    }

    def create_request(
        requestId: str,
        userRequest: str,
        tabId: str,
        pageRevision: int,
        profile: AccessibilityProfile,
        page: PageSnapshot,
        mode: str = "deterministic"
    ) -> AdaptationRequest {
        rules = self.get_applicable_preferences(page.origin, page.url);
        return create_adaptation_request(
            requestId, userRequest, tabId, pageRevision, profile, page, rules, mode
        );
    }

    def create_plan(request: AdaptationRequest) -> PlanResult {
        return create_adaptation_plan(request);
    }

    def explain(plan: AdaptationPlan) -> PlanExplanation {
        return explain_plan(plan);
    }

    def record_apply_result(requestId: str, planId: str, result: str, undoToken: str) {
        record_apply(self.store, requestId, planId, result, undoToken);
    }

    def propose_save(plan: AdaptationPlan) -> PersistenceProposal {
        return propose_persistence(plan);
    }

    def save_approved_preference(
        rule: PreferenceRule, explicitlyApproved: bool
    ) -> PreferenceSaveResult {
        return save_preference(self.store, rule, explicitlyApproved);
    }

    def forward_browser_command(command: BrowserCommand) -> CommandResult {
        return validate_browser_command(command);
    }
}
