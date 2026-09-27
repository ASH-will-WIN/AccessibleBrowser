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

def bounded_identifier(value: any, maximum: int = 120) -> bool {
    return isinstance(value, str) and value.strip() != "" and len(value) <= maximum;
}

def keys_are_allowed(values: dict[str, any], allowed: list[str]) -> bool {
    for key in values.keys() {
        if key not in allowed { return False; }
    }
    return True;
}

def valid_profile(profile: AccessibilityProfile) -> bool {
    return isinstance(profile.textScale, (int, float)) and not isinstance(profile.textScale, bool) and profile.textScale == profile.textScale and profile.textScale >= 1.0 and profile.textScale <= 2.5
        and profile.spacing in ["normal", "comfortable"]
        and profile.contrast in ["normal", "high", "soft"]
        and profile.colorFilter in ["none", "grayscale", "warm", "cool", "invert"]
        and isinstance(profile.readingFont, str) and profile.readingFont.strip() != "" and len(profile.readingFont) <= 80;
}

def validate_adaptation_request(request: AdaptationRequest) -> StructuredError | None {
    if request.schemaVersion != 1 {
        return StructuredError(requestId=request.requestId, code="UNSUPPORTED_VERSION", message="Unsupported adaptation request schema version.", retryable=False);
    }
    if not bounded_identifier(request.requestId) or not bounded_identifier(request.tabId) {
        return StructuredError(requestId=request.requestId, code="INVALID_MESSAGE", message="Adaptation requests require bounded request and tab identifiers.", retryable=False);
    }
    if request.pageRevision < 0 or request.pageRevision != request.page.pageRevision {
        return StructuredError(requestId=request.requestId, code="STALE_PAGE_REVISION", message="The adaptation request does not match the page revision.", retryable=True);
    }
    if request.tabId != request.page.tabId or not bounded_identifier(request.page.snapshotId) {
        return StructuredError(requestId=request.requestId, code="INVALID_MESSAGE", message="The adaptation request does not match the page snapshot.", retryable=False);
    }
    if not valid_profile(request.activeProfile) {
        return StructuredError(requestId=request.requestId, code="INVALID_PARAMETERS", message="The accessibility profile contains unsupported values.", retryable=False);
    }
    if request.userRequest.strip() == "" or len(request.userRequest) > 1000 {
        return StructuredError(requestId=request.requestId, code="INVALID_MESSAGE", message="Accessibility requests must contain 1 to 1000 characters.", retryable=False);
    }
    if request.mode not in ["deterministic", "llm"] {
        return StructuredError(requestId=request.requestId, code="INVALID_MESSAGE", message="Planning mode is not supported.", retryable=False);
    }
    if len(request.applicableRules) > 100 {
        return StructuredError(requestId=request.requestId, code="INVALID_MESSAGE", message="Too many applicable preference rules.", retryable=False);
    }
    return None;
}

def is_allowlisted_action(actionType: str) -> bool {
    return actionType in [
        "set_text_scale",
        "set_spacing",
        "set_contrast",
        "set_color_filter",
        "set_reading_font",
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
    if not bounded_identifier(command.requestId) or not bounded_identifier(command.tabId) or not isinstance(command.arguments, dict) or len(command.arguments) > 8 {
        return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_MESSAGE", message="Browser command metadata or arguments are invalid.", retryable=False));
    }
    allowed = ["new_tab", "close_tab", "switch_tab", "back", "forward", "reload", "navigate", "scroll", "zoom", "search", "read_page", "stop_reading"];
    if command.kind not in allowed {
        return CommandResult(
            ok=False,
            status="rejected",
            error=StructuredError(requestId=command.requestId, code="INVALID_MESSAGE", message="Browser command is not allowlisted.", retryable=False)
        );
    }
    if command.kind in ["close_tab", "back", "forward", "reload", "read_page", "stop_reading"] and len(command.arguments) != 0 {
        return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="This browser command does not accept arguments.", retryable=False));
    }
    if command.kind == "new_tab" {
        if not keys_are_allowed(command.arguments, ["url"]) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="New-tab arguments are restricted to an optional URL.", retryable=False)); }
        if command.arguments.get("url") is not None and not valid_http_url(command.arguments.get("url")) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="New-tab URLs must be HTTP or HTTPS without credentials.", retryable=False)); }
    }
    if command.kind == "switch_tab" {
        if not keys_are_allowed(command.arguments, ["tabId"]) or not bounded_identifier(command.arguments.get("tabId")) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Switch-tab requires a bounded target tab ID.", retryable=False)); }
    }
    if command.kind == "scroll" {
        if not keys_are_allowed(command.arguments, ["deltaY", "deltaX"]) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Scroll arguments are restricted to deltaX and deltaY.", retryable=False)); }
        deltaY = command.arguments.get("deltaY");
        deltaX = command.arguments.get("deltaX", 0);
        if not isinstance(deltaY, (int, float)) or isinstance(deltaY, bool) or not isinstance(deltaX, (int, float)) or isinstance(deltaX, bool) or deltaY != deltaY or deltaX != deltaX or abs(deltaY) > 2000 or abs(deltaX) > 1000 {
            return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Scroll distances are out of bounds.", retryable=False));
        }
    }
    if command.kind == "zoom" {
        if not keys_are_allowed(command.arguments, ["factor"]) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Zoom arguments are restricted to factor.", retryable=False)); }
        factor = command.arguments.get("factor");
        if not isinstance(factor, (int, float)) or isinstance(factor, bool) or factor != factor or (factor as float) < 0.5 or (factor as float) > 2.5 {
            return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Zoom factor must be between 0.5 and 2.5.", retryable=False));
        }
    }
    if command.kind == "search" {
        if not keys_are_allowed(command.arguments, ["searchType", "query", "elementId"]) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Search arguments contain unsupported fields.", retryable=False)); }
        searchType = command.arguments.get("searchType");
        if searchType == "focus_field" {
            elementId = command.arguments.get("elementId");
            if not isinstance(elementId, str) or not bounded_identifier(elementId) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Focus-field search requires an element ID.", retryable=False)); }
        } else {
            query = command.arguments.get("query");
            if searchType not in ["web", "page"] or not isinstance(query, str) or query.strip() == "" or len(query) > 300 { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Search requires web or page and 1 to 300 characters.", retryable=False)); }
        }
    }
    if command.kind == "navigate" {
        if not keys_are_allowed(command.arguments, ["url"]) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Navigation arguments are restricted to url.", retryable=False)); }
        url = command.arguments.get("url");
        if not valid_http_url(url) { return CommandResult(ok=False, status="rejected", error=StructuredError(requestId=command.requestId, code="INVALID_PARAMETERS", message="Navigation requires an HTTP or HTTPS URL without credentials.", retryable=False)); }
    }
    if command.kind == "close_tab" and not command.requiresConfirmation {
        return CommandResult(ok=False, status="cancelled", error=StructuredError(requestId=command.requestId, code="USER_CANCELLED", message="Closing a tab requires confirmation.", retryable=False));
    }
    return CommandResult(ok=True, status="accepted", command=command);
}

def valid_http_url(url: any) -> bool {
    if not isinstance(url, str) or url.strip() == "" or len(url) > 2048 { return False; }
    if "\n" in url or "\r" in url or "\t" in url { return False; }
    lowered = url.lower();
    # The runtime normalizes browser-style input: hostnames receive https://
    # and plain text becomes a Google search. Keep protocol validation here for
    # explicit schemes, while allowing normal address-bar input through.
    if "://" not in lowered {
        if lowered.startswith("javascript:") or lowered.startswith("file:") or lowered.startswith("data:") { return False; }
        return "@" not in url and "%40" not in lowered;
    }
    if not lowered.startswith("http://") and not lowered.startswith("https://") { return False; }
    authority = url.split("://", 1)[1].split("/", 1)[0].split("?", 1)[0].split("#", 1)[0];
    authorityLower = authority.lower();
    return authority != "" and "@" not in authority and " " not in authority and "%40" not in authorityLower;
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

def effective_profile(request: AdaptationRequest) -> AccessibilityProfile {
    profile = AccessibilityProfile(
        textScale=request.activeProfile.textScale,
        spacing=request.activeProfile.spacing,
        contrast=request.activeProfile.contrast,
        colorFilter=request.activeProfile.colorFilter,
        reduceMotion=request.activeProfile.reduceMotion,
        enlargeTargets=request.activeProfile.enlargeTargets,
        readingFont=request.activeProfile.readingFont,
        voiceEnabled=request.activeProfile.voiceEnabled
    );
    selected: dict[str, PreferenceRule] = {};
    scores: dict[str, int] = {};
    for rule in request.applicableRules {
        if not rule.explicitlyApproved { continue; }
        score = 0;
        if rule.scope == "global" { score = 1; }
        if rule.scope == "website" and rule.origin == request.page.origin and rule.origin != "" { score = 2; }
        if rule.scope == "page" and rule.origin == request.page.origin and rule.pageUrl == request.page.url and rule.pageUrl != "" { score = 3; }
        if score == 0 { continue; }
        if score >= scores.get(rule.setting, 0) { selected[rule.setting] = rule; scores[rule.setting] = score; }
    }
    for rule in selected.values() {
        if rule.setting == "textScale" and isinstance(rule.value, (int, float)) { profile.textScale = rule.value as float; }
        if rule.setting == "spacing" and isinstance(rule.value, str) { profile.spacing = rule.value; }
        if rule.setting == "contrast" and isinstance(rule.value, str) { profile.contrast = rule.value; }
        if rule.setting == "colorFilter" and isinstance(rule.value, str) { profile.colorFilter = rule.value; }
        if rule.setting == "reduceMotion" and isinstance(rule.value, bool) { profile.reduceMotion = rule.value; }
        if rule.setting == "enlargeTargets" and isinstance(rule.value, bool) { profile.enlargeTargets = rule.value; }
        if rule.setting == "readingFont" and isinstance(rule.value, str) { profile.readingFont = rule.value; }
    }
    return profile;
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
    profile = effective_profile(request);
    warnings: list[str] = [];

    # Approved saved preferences are reapplied through the same deterministic
    # action contract as a user request. They never invoke the LLM and never
    # create another saved rule.
    if contains_any(lowered, ["apply saved accessibility preferences", "apply saved preferences"]) {
        if request.activeProfile.textScale != profile.textScale {
            actions.append(new_action(actionNumber, "set_text_scale", {"scale": profile.textScale}, "Reapply your approved text-size preference."));
            actionNumber += 1;
        }
        if request.activeProfile.spacing != profile.spacing {
            actions.append(new_action(actionNumber, "set_spacing", {"lineHeight": 1.7 if profile.spacing == "comfortable" else 1.0, "letterSpacing": 0.02 if profile.spacing == "comfortable" else 0.0}, "Reapply your approved spacing preference."));
            actionNumber += 1;
        }
        if request.activeProfile.contrast != profile.contrast {
            actions.append(new_action(actionNumber, "set_contrast", {"level": profile.contrast}, "Reapply your approved contrast preference."));
            actionNumber += 1;
        }
        if request.activeProfile.colorFilter != profile.colorFilter {
            actions.append(new_action(actionNumber, "set_color_filter", {"filter": profile.colorFilter}, "Reapply your approved color-filter preference."));
            actionNumber += 1;
        }
        if request.activeProfile.readingFont != profile.readingFont {
            actions.append(new_action(actionNumber, "set_reading_font", {"font": profile.readingFont}, "Reapply your approved reading-font preference."));
            actionNumber += 1;
        }
        if request.activeProfile.reduceMotion != profile.reduceMotion {
            actions.append(new_action(actionNumber, "reduce_motion", {"enabled": profile.reduceMotion}, "Reapply your approved reduced-motion preference."));
            actionNumber += 1;
        }
        if request.activeProfile.enlargeTargets != profile.enlargeTargets {
            actions.append(new_action(actionNumber, "enlarge_targets", {"enabled": profile.enlargeTargets}, "Reapply your approved target-size preference."));
            actionNumber += 1;
        }
    }

    if contains_any(lowered, ["text larger", "larger text", "make the text larger", "increase text", "bigger text", "restore standard text size", "normal text size"]) {
        targetScale = 1.25;
        if contains_any(lowered, ["restore standard text size", "normal text size", "reset text size"]) { targetScale = 1.0; }
        if profile.textScale != targetScale {
            actions.append(new_action(actionNumber, "set_text_scale", {"scale": targetScale}, "Set text size for easier reading."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["spacing", "more space", "line spacing", "spread out", "restore standard spacing"]) {
        if contains_any(lowered, ["restore standard spacing", "normal spacing", "reset spacing"]) {
            if profile.spacing == "comfortable" { actions.append(new_action(actionNumber, "set_spacing", {"lineHeight": 1.0, "letterSpacing": 0.0}, "Restore standard spacing.")); actionNumber += 1; }
        } elif profile.spacing != "comfortable" {
            actions.append(new_action(actionNumber, "set_spacing", {"lineHeight": 1.7, "letterSpacing": 0.02}, "Increase spacing between readable blocks."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["high contrast", "higher contrast", "contrast", "restore standard contrast"]) {
        targetContrast = "high";
        if contains_any(lowered, ["restore standard contrast", "normal contrast", "reset contrast"]) { targetContrast = "normal"; }
        if profile.contrast != targetContrast {
            actions.append(new_action(actionNumber, "set_contrast", {"level": targetContrast}, "Set foreground and background contrast."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["color filter", "colour filter", "grayscale", "protanopia", "deuteranopia", "tritanopia"]) {
        filterName = "grayscale";
        if contains_any(lowered, ["remove color filter", "remove colour filter", "disable color filter", "disable colour filter", "no color filter", "no colour filter"]) { filterName = "none"; }
        if "warm" in lowered { filterName = "warm"; }
        if "cool" in lowered { filterName = "cool"; }
        if "invert" in lowered { filterName = "invert"; }
        if profile.colorFilter != filterName {
            actions.append(new_action(actionNumber, "set_color_filter", {"filter": filterName}, "Apply the requested color filter."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["reading font", "readable font", "more readable font", "restore the default font", "default font"]) {
        fontName = "reading";
        if contains_any(lowered, ["restore", "default", "normal font"]) { fontName = "default"; }
        if profile.readingFont != fontName {
            actions.append(new_action(actionNumber, "set_reading_font", {"font": fontName}, "Use a more readable font choice."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["reduced motion", "reduce motion", "less animation", "stop animations", "restore normal motion"]) {
        enabled = True;
        if contains_any(lowered, ["restore normal motion", "normal motion", "reset motion"]) { enabled = False; }
        if profile.reduceMotion != enabled {
            actions.append(new_action(actionNumber, "reduce_motion", {"enabled": enabled}, "Set animation and motion effects."));
            actionNumber += 1;
        }
    }
    if contains_any(lowered, ["buttons easier to click", "larger buttons", "larger click", "click targets", "easier to click", "restore standard click targets"]) {
        enabled = True;
        if contains_any(lowered, ["restore standard click targets", "standard click targets", "reset click targets"]) { enabled = False; }
        if profile.enlargeTargets != enabled {
            actions.append(new_action(actionNumber, "enlarge_targets", {"enabled": enabled}, "Set the size and spacing of interactive targets."));
            actionNumber += 1;
        }
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
        if not keys_are_allowed(action.parameters, ["scale"]) { return "set_text_scale only accepts scale"; }
        value = action.parameters.get("scale");
        if value is None { return "scale is required"; }
        if not isinstance(value, (int, float)) or isinstance(value, bool) { return "scale must be numeric"; }
        scale = value as float;
        if scale != scale or scale < 1.0 or scale > 2.5 { return "scale must be between 1.0 and 2.5"; }
    }
    if action.type == "set_spacing" {
        if not keys_are_allowed(action.parameters, ["lineHeight", "letterSpacing"]) { return "set_spacing contains unsupported parameters"; }
        lineHeight = action.parameters.get("lineHeight");
        letterSpacing = action.parameters.get("letterSpacing");
        if lineHeight is None and letterSpacing is None { return "lineHeight or letterSpacing is required"; }
        if lineHeight is not None and (not isinstance(lineHeight, (int, float)) or isinstance(lineHeight, bool) or lineHeight != lineHeight or lineHeight < 1.0 or lineHeight > 2.5) { return "lineHeight must be between 1.0 and 2.5"; }
        if letterSpacing is not None and (not isinstance(letterSpacing, (int, float)) or isinstance(letterSpacing, bool) or letterSpacing != letterSpacing or letterSpacing < 0 or letterSpacing > 0.2) { return "letterSpacing must be between 0 and 0.2"; }
    }
    if action.type == "set_contrast" {
        if not keys_are_allowed(action.parameters, ["level"]) { return "set_contrast only accepts level"; }
        level = action.parameters.get("level");
        if not isinstance(level, str) or level not in ["normal", "high", "soft"] { return "level must be normal, high, or soft"; }
    }
    if action.type == "set_color_filter" {
        if not keys_are_allowed(action.parameters, ["filter"]) { return "set_color_filter only accepts filter"; }
        filterName = action.parameters.get("filter");
        if not isinstance(filterName, str) or filterName not in ["none", "grayscale", "warm", "cool", "invert"] { return "filter is not supported"; }
    }
    if action.type == "set_reading_font" {
        if not keys_are_allowed(action.parameters, ["font"]) { return "set_reading_font only accepts font"; }
        fontName = action.parameters.get("font");
        if not isinstance(fontName, str) or fontName not in ["default", "reading"] { return "font is not supported"; }
    }
    if action.type == "reduce_motion" or action.type == "enlarge_targets" or action.type == "reading_mode" {
        if not keys_are_allowed(action.parameters, ["enabled"]) { return "this action only accepts enabled"; }
        enabled = action.parameters.get("enabled");
        if not isinstance(enabled, bool) { return "enabled must be boolean"; }
    }
    if action.type == "hide_regions" or action.type == "focus_elements" {
        if len(action.parameters) != 0 { return action.type + " does not accept parameters"; }
        if len(action.targetElementIds) == 0 { return action.type + " requires target element IDs"; }
    }
    return "";
}

def validate_plan(plan: AdaptationPlan, request: AdaptationRequest) -> PlanResult {
    requestError = validate_adaptation_request(request);
    if requestError is not None { return PlanResult(ok=False, error=requestError); }
    if plan.schemaVersion != 1 or not bounded_identifier(plan.planId) or plan.requestId != request.requestId or plan.tabId != request.tabId {
        return plan_error(request.requestId, "INVALID_PLAN", "Plan metadata does not match the request.", False);
    }
    if plan.pageRevision != request.pageRevision {
        return plan_error(request.requestId, "STALE_PAGE_REVISION", "The plan was created for a stale page revision.", True);
    }
    if not isinstance(plan.summary, str) or not isinstance(plan.warnings, list) or not isinstance(plan.actions, list) or len(plan.summary) > 1000 or len(plan.warnings) > 30 {
        return plan_error(request.requestId, "INVALID_PLAN", "Plan text is outside the bounded contract.", False);
    }
    for warning in plan.warnings {
        if not isinstance(warning, str) or len(warning) > 500 { return plan_error(request.requestId, "INVALID_PLAN", "Plan warnings are outside the bounded contract.", False); }
    }
    if plan.confidence not in ["high", "medium", "low"] {
        return plan_error(request.requestId, "INVALID_PLAN", "Plan confidence is invalid.", False);
    }
    if plan.suggestedScope not in ["page", "website", "global", "none"] or plan.status not in ["ready", "noOp", "rejected"] {
        return plan_error(request.requestId, "INVALID_PLAN", "Plan status is invalid.", False);
    }
    if plan.status == "ready" and len(plan.actions) == 0 { return plan_error(request.requestId, "INVALID_PLAN", "A ready plan must contain an action.", False); }
    if plan.status == "noOp" and len(plan.actions) != 0 { return plan_error(request.requestId, "INVALID_PLAN", "A no-op plan cannot contain actions.", False); }
    if plan.status == "rejected" { return plan_error(request.requestId, "INVALID_PLAN", "Rejected plans cannot be forwarded for application.", False); }
    if len(plan.actions) > 20 { return plan_error(request.requestId, "INVALID_PLAN", "Plans may contain at most 20 actions.", False); }
    seenActionIds: list[str] = [];
    for action in plan.actions {
        if not isinstance(action.parameters, dict) or not isinstance(action.targetElementIds, list) { return plan_error(request.requestId, "INVALID_PLAN", "Action parameters and targets must be JSON objects and arrays.", False, action.actionId); }
        if not is_allowlisted_action(action.type) {
            return plan_error(request.requestId, "UNSUPPORTED_ACTION", "The plan contains an unsupported action type.", False, action.actionId);
        }
        if not bounded_identifier(action.actionId) or action.actionId in seenActionIds or action.reason.strip() == "" or len(action.reason) > 500 {
            return plan_error(request.requestId, "INVALID_PLAN", "Every action needs an ID and human-readable reason.", False, action.actionId);
        }
        seenActionIds.append(action.actionId);
        if not action.reversible {
            return plan_error(request.requestId, "INVALID_PLAN", "Only reversible actions may be forwarded.", False, action.actionId);
        }
        parameterError = validate_parameters(action);
        if parameterError != "" {
            return plan_error(request.requestId, "INVALID_PARAMETERS", parameterError, False, action.actionId);
        }
        if len(action.targetElementIds) > 100 { return plan_error(request.requestId, "INVALID_PLAN", "An action has too many target element IDs.", False, action.actionId); }
        seenTargetIds: list[str] = [];
        for elementId in action.targetElementIds {
            if not bounded_identifier(elementId) or elementId in seenTargetIds { return plan_error(request.requestId, "INVALID_PLAN", "Target element IDs must be unique and bounded.", False, action.actionId); }
            seenTargetIds.append(elementId);
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
