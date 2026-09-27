"""AccessibleBrowser accessibility planning agent.

This module keeps the accessibility decision-making in Jac while leaving
browser-specific work to Electron through the typed bridge.

The agent:
1. Receives a natural-language or voice request.
2. Combines it with the user's saved accessibility profile.
3. Inspects a page snapshot.
4. Produces only allowlisted, reversible actions.
5. Validates the plan against the current page revision.
6. Records only approved preference changes.
"""

enum ActionKind {
    SCALE_TEXT,
    INCREASE_SPACING,
    IMPROVE_CONTRAST,
    REDUCE_MOTION,
    ENLARGE_TARGETS,
    ADD_FOCUS_OUTLINES,
    APPLY_READING_FONT,
    ENABLE_READING_MODE,
    APPLY_COLOR_FILTER
}

enum RequestSource {
    TEXT,
    VOICE,
    PROFILE
}

enum PlanStatus {
    DRAFT,
    VALIDATED,
    APPLIED,
    UNDONE,
    REJECTED,
    STALE,
    FAILED
}

enum PreferenceOrigin {
    EXPLICIT_REQUEST,
    VOICE_REQUEST,
    APPROVED_PLAN,
    INFERRED_PATTERN
}

obj PageSnapshot {
    has page_id: str;
    has revision: str;
    has url: str;
    has title: str;
    has text_scale: float;
    has contrast_score: float;
    has average_spacing: float;
    has motion_detected: bool;
    has small_targets: int;
    has weak_focus_indicators: bool;
    has article_content: bool;
    has heading_count: int;
    has link_count: int;
    has button_count: int;
    has form_control_count: int;
}

obj AccessibilityProfile {
    has profile_id: str;
    has preferred_text_scale: float;
    has preferred_spacing: float;
    has minimum_contrast: float;
    has reduced_motion: bool;
    has larger_targets: bool;
    has strong_focus_outlines: bool;
    has reading_font: str;
    has reading_mode: bool;
    has color_filter: str;
    has confidence: float;
    has updated_at: str;
}

obj PreferenceMemory {
    has key: str;
    has value: str;
    has confidence: float;
    has times_approved: int;
    has origin: PreferenceOrigin;
    has last_confirmed: str;
}

obj AccessibilityRequest {
    has request_id: str;
    has text: str;
    has source: RequestSource;
    has created_at: str;
    has explicit_action: str;
    has urgency: str;
}

obj ActionParameters {
    has scale: float;
    has spacing_multiplier: float;
    has contrast_ratio: float;
    has filter_name: str;
    has font_family: str;
    has target_min_size: int;
    has focus_width: int;
    has enable: bool;
}

obj PlannedAction {
    has action_id: str;
    has kind: ActionKind;
    has parameters: ActionParameters;
    has reason: str;
    has reversible: bool;
    has requires_confirmation: bool;
    has allowlisted: bool;
    has risk_level: str;
}

obj AdaptationPlan {
    has plan_id: str;
    has page_id: str;
    has page_revision: str;
    has request_id: str;
    has status: PlanStatus;
    has explanation: str;
    has actions: list[PlannedAction];
    has created_at: str;
}

obj AppliedAction {
    has action_id: str;
    has kind: ActionKind;
    has before_value: str;
    has after_value: str;
    has applied_at: str;
}

obj UndoRecord {
    has plan_id: str;
    has page_id: str;
    has page_revision: str;
    has applied_actions: list[AppliedAction];
    has can_undo: bool;
}

obj AgentResult {
    has ok: bool;
    has message: str;
    has plan: AdaptationPlan;
    has profile: AccessibilityProfile;
}

def now_string() -> str {
    return "2026-09-27T00:00:00Z";
}

def make_default_parameters(kind: ActionKind) -> ActionParameters {
    param = ActionParameters(
        scale=1.0,
        spacing_multiplier=1.0,
        contrast_ratio=4.5,
        filter_name="none",
        font_family="system-ui",
        target_min_size=44,
        focus_width=3,
        enable=true
    );

    if kind == ActionKind.SCALE_TEXT {
        param.scale = 1.25;
    }

    if kind == ActionKind.INCREASE_SPACING {
        param.spacing_multiplier = 1.35;
    }

    if kind == ActionKind.IMPROVE_CONTRAST {
        param.contrast_ratio = 7.0;
    }

    if kind == ActionKind.REDUCE_MOTION {
        param.enable = true;
    }

    if kind == ActionKind.ENLARGE_TARGETS {
        param.target_min_size = 48;
    }

    if kind == ActionKind.APPLY_READING_FONT {
        param.font_family = "Atkinson Hyperlegible";
    }

    if kind == ActionKind.APPLY_COLOR_FILTER {
        param.filter_name = "deuteranopia";
    }

    return param;
}

def action_label(kind: ActionKind) -> str {
    if kind == ActionKind.SCALE_TEXT {
        return "Increase text size";
    }

    if kind == ActionKind.INCREASE_SPACING {
        return "Increase spacing";
    }

    if kind == ActionKind.IMPROVE_CONTRAST {
        return "Improve contrast";
    }

    if kind == ActionKind.REDUCE_MOTION {
        return "Reduce motion";
    }

    if kind == ActionKind.ENLARGE_TARGETS {
        return "Enlarge buttons and controls";
    }

    if kind == ActionKind.ADD_FOCUS_OUTLINES {
        return "Strengthen keyboard focus outlines";
    }

    if kind == ActionKind.APPLY_READING_FONT {
        return "Apply a reading-friendly font";
    }

    if kind == ActionKind.ENABLE_READING_MODE {
        return "Enable reading mode";
    }

    if kind == ActionKind.APPLY_COLOR_FILTER {
        return "Apply a color filter";
    }

    return "Unknown accessibility action";
}

def is_allowed(kind: ActionKind) -> bool {
    if kind == ActionKind.SCALE_TEXT {
        return true;
    }

    if kind == ActionKind.INCREASE_SPACING {
        return true;
    }

    if kind == ActionKind.IMPROVE_CONTRAST {
        return true;
    }

    if kind == ActionKind.REDUCE_MOTION {
        return true;
    }

    if kind == ActionKind.ENLARGE_TARGETS {
        return true;
    }

    if kind == ActionKind.ADD_FOCUS_OUTLINES {
        return true;
    }

    if kind == ActionKind.APPLY_READING_FONT {
        return true;
    }

    if kind == ActionKind.ENABLE_READING_MODE {
        return true;
    }

    if kind == ActionKind.APPLY_COLOR_FILTER {
        return true;
    }

    return false;
}

def is_reversible(kind: ActionKind) -> bool {
    return is_allowed(kind);
}

def infer_actions_from_page(
    page: PageSnapshot,
    profile: AccessibilityProfile
) -> list[PlannedAction] {
    actions = [];

    if page.text_scale < profile.preferred_text_scale {
        actions.append(
            PlannedAction(
                action_id="text-scale-001",
                kind=ActionKind.SCALE_TEXT,
                parameters=make_default_parameters(ActionKind.SCALE_TEXT),
                reason="The page text is smaller than the user's preferred size.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if page.average_spacing < profile.preferred_spacing {
        actions.append(
            PlannedAction(
                action_id="spacing-001",
                kind=ActionKind.INCREASE_SPACING,
                parameters=make_default_parameters(ActionKind.INCREASE_SPACING),
                reason="The page uses tighter spacing than the user's preference.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if page.contrast_score < profile.minimum_contrast {
        actions.append(
            PlannedAction(
                action_id="contrast-001",
                kind=ActionKind.IMPROVE_CONTRAST,
                parameters=make_default_parameters(ActionKind.IMPROVE_CONTRAST),
                reason="The page contrast is below the user's minimum preference.",
                reversible=true,
                requires_confirmation=true,
                allowlisted=true,
                risk_level="medium"
            )
        );
    }

    if profile.reduced_motion and page.motion_detected {
        actions.append(
            PlannedAction(
                action_id="motion-001",
                kind=ActionKind.REDUCE_MOTION,
                parameters=make_default_parameters(ActionKind.REDUCE_MOTION),
                reason="The user prefers reduced motion and this page contains motion.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if profile.larger_targets and page.small_targets > 0 {
        actions.append(
            PlannedAction(
                action_id="targets-001",
                kind=ActionKind.ENLARGE_TARGETS,
                parameters=make_default_parameters(ActionKind.ENLARGE_TARGETS),
                reason="Some interactive elements are smaller than the user's target size.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if profile.strong_focus_outlines and page.weak_focus_indicators {
        actions.append(
            PlannedAction(
                action_id="focus-001",
                kind=ActionKind.ADD_FOCUS_OUTLINES,
                parameters=make_default_parameters(ActionKind.ADD_FOCUS_OUTLINES),
                reason="The page has weak keyboard focus indicators.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if profile.reading_font != "system-ui" and page.article_content {
        font_params = make_default_parameters(ActionKind.APPLY_READING_FONT);
        font_params.font_family = profile.reading_font;

        actions.append(
            PlannedAction(
                action_id="font-001",
                kind=ActionKind.APPLY_READING_FONT,
                parameters=font_params,
                reason="The user has a preferred reading font for article content.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if profile.reading_mode and page.article_content {
        actions.append(
            PlannedAction(
                action_id="reading-mode-001",
                kind=ActionKind.ENABLE_READING_MODE,
                parameters=make_default_parameters(ActionKind.ENABLE_READING_MODE),
                reason="The user prefers reading mode for article-like pages.",
                reversible=true,
                requires_confirmation=true,
                allowlisted=true,
                risk_level="medium"
            )
        );
    }

    return actions;
}

def infer_actions_from_request(
    request: AccessibilityRequest,
    profile: AccessibilityProfile,
    page: PageSnapshot
) -> list[PlannedAction] {
    actions = infer_actions_from_page(page, profile);
    text = request.text.lower();

    if text.contains("larger text") or text.contains("bigger text") {
        actions.append(
            PlannedAction(
                action_id="request-text-scale-001",
                kind=ActionKind.SCALE_TEXT,
                parameters=make_default_parameters(ActionKind.SCALE_TEXT),
                reason="The user directly requested larger text.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if text.contains("more spacing") or text.contains("less cramped") {
        actions.append(
            PlannedAction(
                action_id="request-spacing-001",
                kind=ActionKind.INCREASE_SPACING,
                parameters=make_default_parameters(ActionKind.INCREASE_SPACING),
                reason="The user directly requested more spacing.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if text.contains("contrast") or text.contains("easier to see") {
        actions.append(
            PlannedAction(
                action_id="request-contrast-001",
                kind=ActionKind.IMPROVE_CONTRAST,
                parameters=make_default_parameters(ActionKind.IMPROVE_CONTRAST),
                reason="The user requested a more visible page.",
                reversible=true,
                requires_confirmation=true,
                allowlisted=true,
                risk_level="medium"
            )
        );
    }

    if text.contains("stop moving") or text.contains("reduce motion") {
        actions.append(
            PlannedAction(
                action_id="request-motion-001",
                kind=ActionKind.REDUCE_MOTION,
                parameters=make_default_parameters(ActionKind.REDUCE_MOTION),
                reason="The user requested reduced motion.",
                reversible=true,
                requires_confirmation=false,
                allowlisted=true,
                risk_level="low"
            )
        );
    }

    if text.contains("reading mode") or text.contains("focus on the article") {
        actions.append(
            PlannedAction(
                action_id="request-reading-mode-001",
                kind=ActionKind.ENABLE_READING_MODE,
                parameters=make_default_parameters(ActionKind.ENABLE_READING_MODE),
                reason="The user requested a focused reading layout.",
                reversible=true,
                requires_confirmation=true,
                allowlisted=true,
                risk_level="medium"
            )
        );
    }

    return actions;
}

def validate_action(action: PlannedAction) -> bool {
    if not action.allowlisted {
        return false;
    }

    if not is_allowed(action.kind) {
        return false;
    }

    if not action.reversible {
        return false;
    }

    if action.kind == ActionKind.SCALE_TEXT {
        return action.parameters.scale >= 0.8 and action.parameters.scale <= 2.5;
    }

    if action.kind == ActionKind.INCREASE_SPACING {
        return action.parameters.spacing_multiplier >= 1.0
            and action.parameters.spacing_multiplier <= 2.5;
    }

    if action.kind == ActionKind.IMPROVE_CONTRAST {
        return action.parameters.contrast_ratio >= 3.0
            and action.parameters.contrast_ratio <= 21.0;
    }

    if action.kind == ActionKind.ENLARGE_TARGETS {
        return action.parameters.target_min_size >= 40
            and action.parameters.target_min_size <= 96;
    }

    if action.kind == ActionKind.ADD_FOCUS_OUTLINES {
        return action.parameters.focus_width >= 1
            and action.parameters.focus_width <= 8;
    }

    return true;
}

def validate_plan(
    plan: AdaptationPlan,
    current_page: PageSnapshot
) -> AdaptationPlan {
    if plan.page_id != current_page.page_id {
        plan.status = PlanStatus.STALE;
        plan.explanation = "The plan belongs to a different page.";
        return plan;
    }

    if plan.page_revision != current_page.revision {
        plan.status = PlanStatus.STALE;
        plan.explanation = "The page changed before this plan was applied.";
        return plan;
    }

    for action in plan.actions {
        if not validate_action(action) {
            plan.status = PlanStatus.REJECTED;
            plan.explanation = "The plan included an invalid or unsafe action.";
            return plan;
        }
    }

    plan.status = PlanStatus.VALIDATED;
    plan.explanation = "Every action is allowlisted, reversible, and valid.";
    return plan;
}

def update_profile_from_approval(
    profile: AccessibilityProfile,
    memory: list[PreferenceMemory],
    plan: AdaptationPlan
) -> AccessibilityProfile {
    for action in plan.actions {
        if action.kind == ActionKind.SCALE_TEXT {
            profile.preferred_text_scale = action.parameters.scale;
        }

        if action.kind == ActionKind.INCREASE_SPACING {
            profile.preferred_spacing = action.parameters.spacing_multiplier;
        }

        if action.kind == ActionKind.IMPROVE_CONTRAST {
            profile.minimum_contrast = action.parameters.contrast_ratio;
        }

        if action.kind == ActionKind.REDUCE_MOTION {
            profile.reduced_motion = action.parameters.enable;
        }

        if action.kind == ActionKind.ENLARGE_TARGETS {
            profile.larger_targets = true;
        }

        if action.kind == ActionKind.ADD_FOCUS_OUTLINES {
            profile.strong_focus_outlines = true;
        }

        if action.kind == ActionKind.APPLY_READING_FONT {
            profile.reading_font = action.parameters.font_family;
        }

        if action.kind == ActionKind.ENABLE_READING_MODE {
            profile.reading_mode = action.parameters.enable;
        }

        memory.append(
            PreferenceMemory(
                key=action_label(action.kind),
                value="approved",
                confidence=1.0,
                times_approved=1,
                origin=PreferenceOrigin.APPROVED_PLAN,
                last_confirmed=now_string()
            )
        );
    }

    profile.confidence = 1.0;
    profile.updated_at = now_string();
    return profile;
}

def build_plan(
    request: AccessibilityRequest,
    page: PageSnapshot,
    profile: AccessibilityProfile
) -> AdaptationPlan {
    actions = infer_actions_from_request(request, profile, page);

    plan = AdaptationPlan(
        plan_id="plan-" + request.request_id,
        page_id=page.page_id,
        page_revision=page.revision,
        request_id=request.request_id,
        status=PlanStatus.DRAFT,
        explanation="The agent created a reversible accessibility plan.",
        actions=actions,
        created_at=now_string()
    );

    return validate_plan(plan, page);
}

def create_default_profile(profile_id: str) -> AccessibilityProfile {
    return AccessibilityProfile(
        profile_id=profile_id,
        preferred_text_scale=1.25,
        preferred_spacing=1.25,
        minimum_contrast=4.5,
        reduced_motion=true,
        larger_targets=true,
        strong_focus_outlines=true,
        reading_font="Atkinson Hyperlegible",
        reading_mode=false,
        color_filter="none",
        confidence=0.5,
        updated_at=now_string()
    );
}

walker AccessibilityAgent {
    has profile: AccessibilityProfile;
    has memory: list[PreferenceMemory];

    can initialize with entry {
        profile = create_default_profile("default-user");
        memory = [];
        print("AccessibleBrowser accessibility agent initialized.");
    }

    can plan(
        request: AccessibilityRequest,
        page: PageSnapshot
    ) -> AgentResult {
        plan = build_plan(request, page, profile);

        return AgentResult(
            ok=plan.status == PlanStatus.VALIDATED,
            message=plan.explanation,
            plan=plan,
            profile=profile
        );
    }

    can approve(plan: AdaptationPlan) -> AgentResult {
        if plan.status != PlanStatus.VALIDATED {
            return AgentResult(
                ok=false,
                message="Only validated plans can be approved.",
                plan=plan,
                profile=profile
            );
        }

        plan.status = PlanStatus.APPLIED;
        profile = update_profile_from_approval(profile, memory, plan);

        return AgentResult(
            ok=true,
            message="The plan was approved and the accessibility profile was updated.",
            plan=plan,
            profile=profile
        );
    }

    can reject(plan: AdaptationPlan) -> AgentResult {
        plan.status = PlanStatus.REJECTED;

        return AgentResult(
            ok=true,
            message="The plan was rejected and no preference was saved.",
            plan=plan,
            profile=profile
        );
    }

    can undo(plan: AdaptationPlan) -> AgentResult {
        if plan.status != PlanStatus.APPLIED {
            return AgentResult(
                ok=false,
                message="This plan has not been applied.",
                plan=plan,
                profile=profile
            );
        }

        plan.status = PlanStatus.UNDONE;

        return AgentResult(
            ok=true,
            message="The plan is marked as undone. Electron should restore the previous page state.",
            plan=plan,
            profile=profile
        );
    }

    can explain(plan: AdaptationPlan) -> str {
        explanation = "I found " + str(len(plan.actions));
        explanation += " possible accessibility changes for this page.";

        for action in plan.actions {
            explanation += "\n- " + action_label(action.kind);
            explanation += ": " + action.reason;
        }

        return explanation;
    }
}
