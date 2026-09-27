"""Jac-owned accessibility contracts, planning, validation, and explanations.

The objects in this module mirror CONTRACTS.md using camelCase fields so the
bridge can serialize them without a second protocol.  Planning is deliberately
pure: it creates plans but never mutates a page or persists a preference.
"""

obj ElementSummary {
    has elementId: str,
        role: str,
        accessibleName: str,
        text: str = "",
        visible: bool = True,
        disabled: bool = False,
        bounds: dict[str, float] = {},
        metadata: dict[str, any] = {};
}

obj SectionSummary {
    has role: str = "",
        name: str = "";
}

obj PageSnapshot {
    has snapshotId: str,
        tabId: str,
        pageRevision: int,
        url: str,
        origin: str,
        title: str,
        viewport: dict[str, int] = {},
        scroll: dict[str, int] = {},
        elements: list[ElementSummary] = [],
        sections: list[SectionSummary] = [],
        contentSummary: str = "",
        pageMetadata: dict[str, any] = {};
}

obj AccessibilityProfile {
    has textScale: float = 1.0,
        spacing: str = "normal",
        contrast: str = "normal",
        colorFilter: str = "none",
        reduceMotion: bool = False,
        enlargeTargets: bool = False,
        readingFont: str = "default",
        voiceEnabled: bool = False;
}

obj PreferenceRule {
    has setting: str,
        value: any,
        scope: str,
        source: str,
        explicitlyApproved: bool,
        createdAt: str,
        updatedAt: str,
        origin: str = "",
        pageUrl: str = "";
}

obj AdaptationRequest {
    has schemaVersion: int,
        requestId: str,
        tabId: str,
        pageRevision: int,
        userRequest: str,
        activeProfile: AccessibilityProfile,
        page: PageSnapshot,
        applicableRules: list[PreferenceRule] = [],
        mode: str = "deterministic";
}

obj PlanAction {
    has actionId: str,
        type: str,
        parameters: dict[str, any],
        reason: str,
        reversible: bool,
        targetElementIds: list[str] = [];
}

obj AdaptationPlan {
    has schemaVersion: int,
        planId: str,
        requestId: str,
        tabId: str,
        pageRevision: int,
        summary: str,
        actions: list[PlanAction],
        confidence: str,
        warnings: list[str],
        suggestedScope: str,
        status: str;
}

obj BrowserCommand {
    has schemaVersion: int,
        requestId: str,
        tabId: str,
        kind: str,
        arguments: dict[str, any],
        requiresConfirmation: bool;
}

obj StructuredError {
    has requestId: str,
        code: str,
        message: str,
        retryable: bool,
        failedActionId: str = "";
}

obj PlanResult {
    has ok: bool,
        plan: AdaptationPlan | None = None,
        error: StructuredError | None = None;
}

obj PlanExplanation {
    has whatWillChange: str,
        affectedParts: list[str],
        whySuggested: str,
        confidence: str,
        warnings: list[str],
        reversible: bool,
        persistenceOptions: list[str];
}

obj PersistenceProposal {
    has suggestedScope: str,
        options: list[str],
        requiresExplicitApproval: bool,
        message: str;
}

obj CommandResult {
    has ok: bool,
        status: str,
        command: BrowserCommand | None = None,
        error: StructuredError | None = None;
}

obj ApplyRecord {
    has requestId: str,
        planId: str,
        result: str,
        undoToken: str,
        createdAt: str;
}

def plan_error(requestId: str, code: str, message: str, retryable: bool, failedActionId: str = "") -> PlanResult {
    return PlanResult(
        ok=False,
        error=StructuredError(
            requestId=requestId,
            code=code,
            message=message,
            retryable=retryable,
            failedActionId=failedActionId
        )
    );
}

def is_allowlisted_action(actionType: str) -> bool {
    return actionType in [
        "set_text_scale",
        "set_spacing",
        "set_contrast",
        "set_color_filter",
        "reduce_motion",
        "enlarge_targets",
        "hide_regions",
        "reading_mode",
        "focus_elements"
    ];
}

def create_adaptation_request(requestId: str, userRequest: str, tabId: str, pageRevision: int, profile: AccessibilityProfile, page: PageSnapshot, rules: list[PreferenceRule] | None = None, mode: str = "deterministic") -> AdaptationRequest {
    applicableRules: list[PreferenceRule] = [];
    if rules is not None { applicableRules = rules; }
    return AdaptationRequest(
        schemaVersion=1,
        requestId=requestId,
        tabId=tabId,
        pageRevision=pageRevision,
        userRequest=userRequest,
        activeProfile=profile,
        page=page,
        applicableRules=applicableRules,
        mode=mode
    );
}

def propose_persistence(plan: AdaptationPlan) -> PersistenceProposal {
    options: list[str] = ["just for now", "this page", "this website", "all websites"];
    if plan.suggestedScope == "none" { options = ["just for now"]; }
    return PersistenceProposal(
        suggestedScope=plan.suggestedScope,
        options=options,
        requiresExplicitApproval=True,
        message="Applying a plan never saves it automatically. Choose a scope and explicitly approve it."
    );
}

def validate_browser_command(command: BrowserCommand) -> CommandResult {
    if command.schemaVersion != 1 {
        return CommandResult(
            ok=False,
            status="rejected",
            error=StructuredError(requestId=command.requestId, code="UNSUPPORTED_VERSION", message="Unsupported browser command schema version.", retryable=False)
        );
    }
    allowed = ["new_tab", "close_tab", "switch_tab", "back", "forward", "reload", "navigate", "scroll", "zoom", "search", "read_page", "stop_reading"];
    if command.kind not in allowed {
        return CommandResult(
            ok=False,
            status="rejected",
            error=StructuredError(requestId=command.requestId, code="INVALID_MESSAGE", message="Browser command is not allowlisted.", retryable=False)
        );
    }
    if command.kind == "scroll" {
        deltaY = command.arguments.get("deltaY");
        deltaX = command.arguments.get("deltaX", 0);
        if not isinstance(deltaY, (int, float)) or not isinstance(deltaX, (int, float)) or abs(deltaY) > 2000 or abs(deltaX) > 1000 {
            return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Scroll distances are out of bounds.", retryable=False));
        }
    }
    if command.kind == "zoom" {
        factor = command.arguments.get("factor");
        if not isinstance(factor, (int, float)) or (factor as float) < 0.5 or (factor as float) > 2.5 {
            return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Zoom factor must be between 0.5 and 2.5.", retryable=False));
        }
    }
    if command.kind == "search" {
        searchType = command.arguments.get("searchType");
        if searchType == "focus_field" {
            elementId = command.arguments.get("elementId");
            if not isinstance(elementId, str) or elementId == "" { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Focus-field search requires an element ID.", retryable=False)); }
        } else {
            query = command.arguments.get("query");
            if searchType not in ["web", "page"] or not isinstance(query, str) or query.strip() == "" or len(query) > 300 { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Search requires web or page and 1 to 300 characters.", retryable=False)); }
        }
    }
    if command.kind == "navigate" {
        url = command.arguments.get("url");
        if not isinstance(url, str) or url.strip() == "" or len(url) > 2048 { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Navigation requires a URL under 2048 characters.", retryable=False)); }
    }
    if command.kind == "close_tab" and not command.requiresConfirmation {
        return CommandResult(ok=False, status="cancelled", error=StructuredError(requestId=command.requestId, code="USER_CANCELLED", message="Closing a tab requires confirmation.", retryable=False));
    }
    return CommandResult(ok=True, status="accepted", command=command);
}

def requested_scope(userRequest: str) -> str {
    lowered = userRequest.lower();
    if "just for now" in lowered or "for now" in lowered {
        return "none";
    }
    if "every website" in lowered or "all websites" in lowered or "always" in lowered {
        return "global";
    }
    if "this website" in lowered or "on this site" in lowered {
        return "website";
    }
    return "page";
}

def new_action(actionNumber: int, actionType: str, parameters: dict[str, any], reason: str, targetElementIds: list[str] | None = None) -> PlanAction {
    targets: list[str] = [];
    if targetElementIds is not None { targets = targetElementIds; }
    return PlanAction(
        actionId="action_" + str(actionNumber),
        type=actionType,
        parameters=parameters,
        reason=reason,
        reversible=True,
        targetElementIds=targets
    );
}

def contains_any(text: str, terms: list[str]) -> bool {
    for term in terms {
        if term in text { return True; }
    }
    return False;
}

def deterministic_plan(request: AdaptationRequest) -> PlanResult {
    lowered = request.userRequest.lower().strip();
    if lowered == "" {
        return plan_error(request.requestId, "INVALID_MESSAGE", "The accessibility request is empty.", False);
    }
    if contains_any(lowered, ["javascript", "arbitrary css", "shell command", "execute code", "run code"]) {
        return plan_error(request.requestId, "INVALID_PLAN", "Only allowlisted, reversible accessibility actions are supported; executable code is never accepted.", False);
    }

    actions: list[PlanAction] = [];
    actionNumber = 1;
    profile = request.activeProfile;
    warnings: list[str] = [];

    if contains_any(lowered, ["text larger", "larger text", "make the text larger", "increase text", "bigger text"]) {
        if profile.textScale < 1.2 {
            actions.append(new_action(actionNumber, "set_text_scale", {"scale": 1.25}, "Increase text size for easier reading."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["spacing", "more space", "line spacing", "spread out"]) and profile.spacing != "comfortable" {
            actions.append(new_action(actionNumber, "set_spacing", {"lineHeight": 1.7, "letterSpacing": 0.02}, "Increase spacing between readable blocks."));
        actionNumber += 1;
    }
    if contains_any(lowered, ["high contrast", "higher contrast", "contrast"]) and profile.contrast != "high" {
            actions.append(new_action(actionNumber, "set_contrast", {"level": "high"}, "Increase contrast between foreground and background."));
        actionNumber += 1;
    }
    if contains_any(lowered, ["color filter", "colour filter", "grayscale", "protanopia", "deuteranopia", "tritanopia"]) {
        filterName = "grayscale";
        if "warm" in lowered { filterName = "warm"; }
        if "cool" in lowered { filterName = "cool"; }
        if "invert" in lowered { filterName = "invert"; }
        if profile.colorFilter != filterName {
            actions.append(new_action(actionNumber, "set_color_filter", {"filter": filterName}, "Apply the requested color filter."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["reduced motion", "reduce motion", "less animation", "stop animations"]) and not profile.reduceMotion {
        actions.append(new_action(actionNumber, "reduce_motion", {"enabled": True}, "Reduce animation and motion effects."));
        actionNumber += 1;
    }
    if contains_any(lowered, ["buttons easier to click", "larger buttons", "larger click", "click targets", "easier to click"]) and not profile.enlargeTargets {
            actions.append(new_action(actionNumber, "enlarge_targets", {"enabled": True}, "Increase the size and spacing of interactive targets."));
        actionNumber += 1;
    }
    if contains_any(lowered, ["reading mode", "simplify the page", "easier to read"]) {
        actions.append(new_action(actionNumber, "reading_mode", {"enabled": True}, "Present the page in a focused reading layout."));
        actionNumber += 1;
    }
    if contains_any(lowered, ["focus", "highlight what i am reading", "highlight elements"]) {
        if len(request.page.elements) > 0 {
            actions.append(new_action(actionNumber, "focus_elements", {}, "Focus the first relevant page element.", [request.page.elements[0].elementId]));
            actionNumber += 1;
        } else {
            warnings.append("The page snapshot has no focusable element IDs for a targeted focus action.");
        }
    }

    if len(request.page.elements) == 0 and contains_any(lowered, ["buttons", "click", "focus", "highlight"]) {
        warnings.append("The page snapshot has no element IDs, so targeted actions will be preview-only until the page is refreshed.");
    }
    status = "ready";
    summary = "Prepared an accessibility adaptation plan.";
    if len(actions) == 0 {
        status = "noOp";
        summary = "No accessibility changes are needed for the active profile.";
    }
    plan = AdaptationPlan(
        schemaVersion=1,
        planId="plan_" + request.requestId,
        requestId=request.requestId,
        tabId=request.tabId,
        pageRevision=request.pageRevision,
        summary=summary,
        actions=actions,
        confidence="high",
        warnings=warnings,
        suggestedScope=requested_scope(request.userRequest),
        status=status
    );
    return validate_plan(plan, request);
}

def validate_parameters(action: PlanAction) -> str {
    if action.type == "set_text_scale" {
        value = action.parameters.get("scale");
        if value is None { return "scale is required"; }
        if not isinstance(value, (int, float)) { return "scale must be numeric"; }
        scale = value as float;
        if scale < 1.0 or scale > 2.5 { return "scale must be between 1.0 and 2.5"; }
    }
    if action.type == "set_spacing" {
        lineHeight = action.parameters.get("lineHeight");
        letterSpacing = action.parameters.get("letterSpacing");
        if lineHeight is None and letterSpacing is None { return "lineHeight or letterSpacing is required"; }
        if lineHeight is not None and (not isinstance(lineHeight, (int, float)) or lineHeight < 1.0 or lineHeight > 2.5) { return "lineHeight must be between 1.0 and 2.5"; }
        if letterSpacing is not None and (not isinstance(letterSpacing, (int, float)) or letterSpacing < 0 or letterSpacing > 0.2) { return "letterSpacing must be between 0 and 0.2"; }
    }
    if action.type == "set_contrast" {
        level = action.parameters.get("level");
        if not isinstance(level, str) or level not in ["high", "soft"] { return "level must be high or soft"; }
    }
    if action.type == "set_color_filter" {
        filterName = action.parameters.get("filter");
        if not isinstance(filterName, str) or filterName not in ["grayscale", "warm", "cool", "invert"] { return "filter is not supported"; }
    }
    if action.type == "reduce_motion" or action.type == "enlarge_targets" or action.type == "reading_mode" {
        enabled = action.parameters.get("enabled");
        if not isinstance(enabled, bool) { return "enabled must be boolean"; }
    }
    if action.type == "focus_elements" and len(action.targetElementIds) == 0 {
        return "focus_elements requires target element IDs";
    }
    return "";
}

def validate_plan(plan: AdaptationPlan, request: AdaptationRequest) -> PlanResult {
    if plan.schemaVersion != 1 or plan.requestId != request.requestId or plan.tabId != request.tabId {
        return plan_error(request.requestId, "INVALID_PLAN", "Plan metadata does not match the request.", False);
    }
    if plan.pageRevision != request.pageRevision {
        return plan_error(request.requestId, "STALE_PAGE_REVISION", "The plan was created for a stale page revision.", True);
    }
    if plan.confidence not in ["high", "medium", "low"] {
        return plan_error(request.requestId, "INVALID_PLAN", "Plan confidence is invalid.", False);
    }
    if plan.status not in ["ready", "noOp", "rejected"] {
        return plan_error(request.requestId, "INVALID_PLAN", "Plan status is invalid.", False);
    }
    for action in plan.actions {
        if not is_allowlisted_action(action.type) {
            return plan_error(request.requestId, "UNSUPPORTED_ACTION", "The plan contains an unsupported action type.", False, action.actionId);
        }
        if action.actionId == "" or action.reason == "" {
            return plan_error(request.requestId, "INVALID_PLAN", "Every action needs an ID and human-readable reason.", False, action.actionId);
        }
        if not action.reversible {
            plan.warnings.append("One action is not reversible and requires explicit preview approval.");
        }
        parameterError = validate_parameters(action);
        if parameterError != "" {
            return plan_error(request.requestId, "INVALID_PARAMETERS", parameterError, False, action.actionId);
        }
        for elementId in action.targetElementIds {
            found = False;
            for element in request.page.elements {
                if element.elementId == elementId { found = True; }
            }
            if not found {
                return plan_error(request.requestId, "TARGET_NOT_FOUND", "An action refers to an element outside the current page snapshot.", True, action.actionId);
            }
        }
    }
    return PlanResult(ok=True, plan=plan);
}

def explain_plan(plan: AdaptationPlan) -> PlanExplanation {
    affected: list[str] = [];
    changes: list[str] = [];
    for action in plan.actions {
        affected.append(action.type);
        changes.append(action.reason);
    }
    if len(changes) == 0 { changes.append("No page changes will be made."); }
    persistenceOptions: list[str] = ["just for now", "this page", "this website", "all websites"];
    if plan.suggestedScope == "none" { persistenceOptions = ["just for now"]; }
    reversible = True;
    for action in plan.actions {
        if not action.reversible { reversible = False; }
    }
    return PlanExplanation(
        whatWillChange=" ".join(changes),
        affectedParts=affected,
        whySuggested="The plan maps the request to allowlisted accessibility actions.",
        confidence=plan.confidence,
        warnings=plan.warnings,
        reversible=reversible,
        persistenceOptions=persistenceOptions
    );
}
